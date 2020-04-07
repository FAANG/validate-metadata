import xlrd
import os
from metadata_validation_conversion.constants import ALLOWED_SHEET_NAMES, \
    SKIP_PROPERTIES, SPECIAL_PROPERTIES, JSON_TYPES, \
    SAMPLES_SPECIFIC_JSON_TYPES, EXPERIMENTS_SPECIFIC_JSON_TYPES, \
    CHIP_SEQ_INPUT_DNA_JSON_TYPES, CHIP_SEQ_DNA_BINDING_PROTEINS_JSON_TYPES, \
    EXPERIMENT_ALLOWED_SPECIAL_SHEET_NAMES, CHIP_SEQ_MODULE_RULES
from metadata_validation_conversion.helpers import convert_to_snake_case, \
    get_rules_json


class ReadExcelFile:
    def __init__(self, file_path, json_type):
        self.file_path = file_path
        self.json_type = json_type
        self.headers = list()
        self.array_fields = list()
        self.wb_datemode = None

    def start_conversion(self):
        """
        Main function that will convert xlsx file to proper json format
        :return: submitted data in proper json format
        """
        wb = xlrd.open_workbook(self.file_path)
        self.wb_datemode = wb.datemode
        # keys are sheet names and values are lists of dicts, each element in the list is one row
        data = dict()
        structure = dict()
        for sh in wb.sheets():
            if sh.name not in ALLOWED_SHEET_NAMES:
                if sh.name == 'faang_field_values':
                    # TODO: read in the limited values for columns, particularly for fields not in the ruleset
                    # TODO: the ones limited in ENA e.g. existing_study_type
                    continue
                elif sh.name in EXPERIMENT_ALLOWED_SPECIAL_SHEET_NAMES:
                    special_sheet_data = self.get_experiments_additional_data(sh)
                    if 'Error' in special_sheet_data:
                        os.remove(self.file_path)
                        return special_sheet_data, structure
                    data[convert_to_snake_case(sh.name)] = special_sheet_data
                    continue
                else:
                    os.remove(self.file_path)
                    return f"Error: there are no rules for {sh.name} type!", \
                           structure
            else:
                tmp = list()
                self.headers = [
                    convert_to_snake_case(item) for item in sh.row_values(0)]
                try:
                    field_names_indexes = self.get_field_names_and_indexes(
                        sh.name)
                    structure[convert_to_snake_case(sh.name)] = \
                        field_names_indexes
                except ValueError as err:
                    os.remove(self.file_path)
                    return err.args[0], structure
                for row_number in range(1, sh.nrows):
                    sample_data = self.get_sample_data(
                        sh.row_values(row_number), field_names_indexes, sh.name)
                    material_consistency = \
                        self.check_sheet_name_material_consistency(sample_data,
                                                                   sh.name)
                    if material_consistency is not False:
                        os.remove(self.file_path)
                        return material_consistency, structure
                    if self.check_sample(sample_data):
                        tmp.append(sample_data)
                if len(tmp) > 0:
                    data[convert_to_snake_case(sh.name)] = tmp
        os.remove(self.file_path)
        return data, structure

    def get_experiments_additional_data(self, sheet):
        """
        This function will parse non assay type specific sheets in the experiment template
        the returned data is a list of rows, each row is represented as a dict with filed name as key and value as value
        :param sheet: object to get data from
        :return: parsed data
        """
        sheet_name = sheet.name
        data = list()
        sheet_fields = EXPERIMENT_ALLOWED_SPECIAL_SHEET_NAMES[sheet_name]
        for row_number in range(1, sheet.nrows):
            tmp = dict()
            for index, field_name in enumerate(sheet_fields['all']):
                try:
                    tmp[field_name] = sheet.row_values(row_number)[index]
                    # Convert date data to string (as Excel stores date in float format)
                    # According to https://xlrd.readthedocs.io/en/latest/dates.html, using this package’s
                    # xldate_as_tuple() function to convert numbers from a workbook, you must use
                    # the datemode attribute of the Book object
                    if field_name == 'run_date':
                        # noinspection PyPep8Naming
                        y, m, d, H, M, S = xlrd.xldate_as_tuple(sheet.row_values(row_number)[index], self.wb_datemode)
                        m = self.add_leading_zero(m)
                        d = self.add_leading_zero(d)
                        # noinspection PyPep8Naming
                        H = self.add_leading_zero(H)
                        # noinspection PyPep8Naming
                        M = self.add_leading_zero(M)
                        # noinspection PyPep8Naming
                        S = self.add_leading_zero(S)
                        cell_value = f"{y}-{m}-{d}T{H}:{M}:{S}"
                        tmp[field_name] = cell_value

                except IndexError:
                    if field_name in sheet_fields['mandatory']:
                        return f'Error: {field_name} field is mandatory in sheet {sheet_name}'
                if field_name in sheet_fields['mandatory'] \
                        and tmp[field_name] == '':
                    return f'Error: mandatory field {field_name} in sheet {sheet_name} cannot have empty value'
            data.append(tmp)
        return data

    def get_field_names_and_indexes(self, sheet_name):
        """
        This function will create dict with field_names as keys and field
        sub_names
        with its indices inside template as values
        :return dict with core and type field_names and indexes
        """
        field_names = dict()
        array_fields = list()
        field_names_and_indexes = dict()

        url = ALLOWED_SHEET_NAMES[sheet_name]
        # Check for chip-seq module rules
        if sheet_name in CHIP_SEQ_MODULE_RULES:
            type_json, core_json, module_json = get_rules_json(
                url, self.json_type, CHIP_SEQ_MODULE_RULES[sheet_name])
            field_names['module'], tmp = self.parse_json(module_json)
            array_fields.extend(tmp)
            field_names['core'], tmp = self.parse_json(core_json)
            array_fields.extend(tmp)
        # this experiment sheets will only have type rules
        elif sheet_name in ['faang', 'ena', 'eva']:
            type_json = get_rules_json(url, self.json_type)
        else:
            type_json, core_json = get_rules_json(url, self.json_type)
            field_names['core'], tmp = self.parse_json(core_json)
            array_fields.extend(tmp)

        field_names['type'], tmp = self.parse_json(type_json)
        array_fields.extend(tmp)
        field_names['custom'], tmp = self.get_custom_data_fields(field_names,
                                                                 sheet_name)
        array_fields.extend(tmp)

        for core_property, data_property in field_names.items():
            subtype_name_and_indexes = dict()
            for field_name, field_types in data_property.items():
                subtype_name_and_indexes[field_name] = self.get_indices(
                    field_name, field_types, array_fields)
            field_names_and_indexes[core_property] = subtype_name_and_indexes
        return field_names_and_indexes

    @staticmethod
    def parse_json(json_to_parse):
        """
        This function will parse json and return field names with positions
        :param json_to_parse: json file that should be parsed
        :return: dict with field_names as keys and field sub_names as values
        """
        required_fields = dict()
        array_fields = list()
        for pr_property, value in json_to_parse['properties'].items():
            if pr_property not in SKIP_PROPERTIES and value['type'] == 'object':
                required_fields.setdefault(pr_property, [])
                for sc_property in value['required']:
                    required_fields[pr_property].append(sc_property)
            elif pr_property not in SKIP_PROPERTIES and \
                    value['type'] == 'array':
                array_fields.append(pr_property)
                required_fields.setdefault(pr_property, [])
                for sc_property in value['items']['required']:
                    required_fields[pr_property].append(sc_property)
        return required_fields, array_fields

    def get_custom_data_fields(self, field_names, sheet_name):
        """
        This function will go through headers and find all remaining names that
        are not in field_names
        :param field_names: names from json-schema
        :param sheet_name: name of the sheet
        :return: rules for custom fields in dict and all array fields
        """
        custom_data_fields_indexes = dict()
        array_fields = list()
        if sheet_name in CHIP_SEQ_MODULE_RULES:
            headers_to_check = {**field_names['core'], **field_names['type'],
                                **field_names['module']}
        elif sheet_name in ['faang', 'ena', 'eva']:
            headers_to_check = {**field_names['type']}
        else:
            headers_to_check = {**field_names['core'], **field_names['type']}
        for header in self.headers:
            if header not in headers_to_check and header not in \
                    SPECIAL_PROPERTIES:
                indexes = self.return_all_indexes(header)
                if len(indexes) > 1:
                    array_fields.append(header)
                if len(self.headers)-1 > (indexes[0] + 1) and \
                        self.headers[indexes[0] + 1] == 'unit':
                    custom_data_fields_indexes[header] = ['value', 'units']
                elif len(self.headers)-1 > (indexes[0] + 1) and \
                        self.headers[indexes[0] + 1] == 'term_source_id':
                    custom_data_fields_indexes[header] = ['text', 'term']
                else:
                    custom_data_fields_indexes[header] = ['value']
        return custom_data_fields_indexes, array_fields

    def return_all_indexes(self, item_to_check):
        """
        This function will return array of all indexes of iterm in array
        :param item_to_check: item to search
        :return:
        """
        return [index for index, value in enumerate(self.headers) if value ==
                item_to_check]

    def get_indices(self, field_name, field_types, array_fields):
        """
        This function will return position of fields in template
        :param field_name: name of the field
        :param field_types: types that this field has
        :param array_fields
        :return: dict with positions of types of field
        """
        if field_name not in self.headers:
            raise ValueError(
                f"Error: can't find this property '{field_name}' in "
                f"headers")
        if len(field_types) == 1 and 'value' in field_types:
            indices = self.return_all_indexes(field_name)
            if len(indices) == 1 and field_name not in array_fields:
                return {'value': indices[0]}
            elif (len(indices) > 1 and field_name in array_fields) or \
                    (field_name in array_fields):
                indices_list = list()
                for index in indices:
                    indices_list.append({'value': index})
                return indices_list
            else:
                raise ValueError(f"Error: multiple entries for attribute "
                                 f"'{field_name}' present")
        else:
            if field_types == ['value', 'units']:
                value_indices = self.return_all_indexes(field_name)
                if len(value_indices) == 1 and field_name not in array_fields:
                    return self.check_field_existence(value_indices[0],
                                                      field_name, 'value',
                                                      'unit')
                elif (len(value_indices) > 1 and field_name in array_fields) \
                        or (field_name in array_fields):
                    indices_list = list()
                    for index in value_indices:
                        indices_list.append(
                            self.check_field_existence(index, field_name,
                                                       'value', 'unit'))
                    return indices_list
                else:
                    raise ValueError(f"Error: multiple entries for attribute "
                                     f"'{field_name}' present")
            elif field_types == ['text', 'term']:
                text_indices = self.return_all_indexes(field_name)
                if len(text_indices) == 1 and field_name not in array_fields:
                    return self.check_field_existence(text_indices[0],
                                                      field_name, 'text',
                                                      'term_source_id')
                elif (len(text_indices) > 1 and field_name in array_fields) \
                        or (field_name in array_fields):
                    indices_list = list()
                    for index in text_indices:
                        indices_list.append(
                            self.check_field_existence(index, field_name,
                                                       'text',
                                                       'term_source_id'))
                    return indices_list
                else:
                    raise ValueError(f"Error: multiple entries for attribute "
                                     f"'{field_name}' present")
            else:
                raise ValueError(f"Error: unknown types present for attribute "
                                 f"'{field_types}' present")

    def check_field_existence(self, index, field, first_subfield,
                              second_subfield):
        """
        This function will check whether table has all required fields
        :param index: index to check in table
        :param field: field name
        :param first_subfield: first subfield name
        :param second_subfield: second subfield name
        :return: dict with subfield indexes
        """
        if self.headers[index + 1] != second_subfield:
            raise ValueError(
                f"Error: this property {field} doesn't have {second_subfield} "
                f"provided in template!")
        else:
            if second_subfield == 'unit':
                second_subfield = 'units'
            elif second_subfield == 'term_source_id':
                second_subfield = 'term'
            return {first_subfield: index, second_subfield: index + 1}

    def get_sample_data(self, input_data, field_names_indexes, name):
        """
        This function will fetch information about organism
        :param input_data: row from template to fetch information from
        :param field_names_indexes: dict with field names and indexes from json
        :param name: name of the sheet
        :return: dict with required information
        """
        organism_to_validate = dict()
        if name == 'chip-seq input dna':
            json_types = {**EXPERIMENTS_SPECIFIC_JSON_TYPES, **JSON_TYPES,
                          **CHIP_SEQ_INPUT_DNA_JSON_TYPES}
        elif name == 'chip-seq dna-binding proteins':
            json_types = {**EXPERIMENTS_SPECIFIC_JSON_TYPES, **JSON_TYPES,
                          **CHIP_SEQ_DNA_BINDING_PROTEINS_JSON_TYPES}
        else:
            if self.json_type == 'samples':
                json_types = {**SAMPLES_SPECIFIC_JSON_TYPES, **JSON_TYPES}
            elif self.json_type == 'analyses':
                json_types = {**JSON_TYPES}
            else:
                json_types = {**EXPERIMENTS_SPECIFIC_JSON_TYPES, **JSON_TYPES}
        for k, v in json_types.items():
            if v is not None:
                organism_to_validate.setdefault(v, dict())
                for field_name, indexes in field_names_indexes[k].items():
                    date_field = self.check_cell_is_date(field_name)
                    self.add_row(field_name, indexes, organism_to_validate[v],
                                 input_data, date_field)
            else:
                for field_name, indexes in field_names_indexes[k].items():
                    date_field = self.check_cell_is_date(field_name)
                    self.add_row(field_name, indexes, organism_to_validate,
                                 input_data, date_field)
        return organism_to_validate

    @staticmethod
    def check_cell_is_date(field_name):
        """
        This function will check that current column is date field
        :param field_name: name of column
        :return: True if column is date and False otherwise
        """
        if 'date' in field_name:
            return True
        else:
            return False

    def add_row(self, field_name, indexes, organism_to_validate, input_data,
                date_field):
        """
        High-level function to get data from table
        :param field_name: name of the field to add
        :param indexes: subfields of this field
        :param organism_to_validate: results holder
        :param input_data: row from table
        :param date_field: date field to check
        """
        if isinstance(indexes, list):
            tmp_list = list()
            for index in indexes:
                tmp_data = self.get_data(input_data, date_field, **index)
                if len(tmp_data) != 0:
                    tmp_list.append(tmp_data)
            if len(tmp_list) != 0:
                organism_to_validate[field_name] = tmp_list
        else:
            self.check_existence(field_name, organism_to_validate,
                                 self.get_data(input_data, date_field,
                                               **indexes))

    def get_data(self, input_data, date_field, **fields):
        """
        This function will create dict with required fields and required
        information
        :param input_data: row from template
        :param date_field: boolean value is this data is date data
        :param fields: dict with field name as key and field index as value
        :return: dict with required information
        """
        data_to_return = dict()
        for field_name, field_index in fields.items():
            cell_value = input_data[field_index]
            if cell_value != '':
                # Convert all "_" in term ids to ":" as required by validator
                if field_name == 'term' and "_" in cell_value:
                    cell_value = cell_value.replace("_", ":")

                # Convert date data to string (as Excel stores date in float format)
                # According to https://xlrd.readthedocs.io/en/latest/dates.html, using this package’s xldate_as_tuple()
                # function to convert numbers from a workbook, you must use the datemode attribute of the Book object
                if date_field is True and isinstance(cell_value, float):
                    y, m, d, _, _, _ = xlrd.xldate_as_tuple(cell_value,
                                                            self.wb_datemode)
                    m = self.add_leading_zero(m)
                    d = self.add_leading_zero(d)
                    cell_value = f"{y}-{m}-{d}"
                data_to_return[field_name] = cell_value
        return data_to_return

    @staticmethod
    def check_existence(field_name, data_to_validate, template_data):
        """
        This function will check whether template_data has required field
        :param field_name: name of field
        :param data_to_validate: data dict for validation
        :param template_data: template data to check
        """
        if len(template_data) != 0:
            data_to_validate[field_name] = template_data

    @staticmethod
    def add_leading_zero(date_item):
        """
        This function will add leading zero if date is just one number
        :param date_item: item to check
        :return: date item in proper format (01, 02, etc...)
        """
        if date_item < 10:
            return f"0{date_item}"
        else:
            return date_item

    def check_sheet_name_material_consistency(self, sample_data, name):
        """
        This function checks that sheet has consistent material
        :param sample_data: data to check
        :param name: name of sheet
        :return: False or error
        """
        if self.json_type != 'samples':
            return False
        if 'samples_core' in sample_data and 'material' in \
                sample_data['samples_core'] and 'text' in \
                sample_data['samples_core']['material']:
            material = sample_data['samples_core']['material']['text']
            if material != name:
                return f"Error: '{name}' sheet contains record with " \
                       f"inconsistent material '{material}'"
            else:
                return False
        else:
            return f"Error: '{name}' sheet contains records with empty material"

    @staticmethod
    def check_sample(sample):
        """
        This function will check that sample is not empty
        :param sample: sample to check
        :return: True if sample should be added to data and False otherwise
        """
        if 'experiments_core' in sample and len(sample) <= 3:
            if 'input_dna' in sample:
                if len(sample['input_dna']) > 0:
                    return True
                return False
            elif 'binding_proteins' in sample:
                if len(sample['binding_proteins']) > 0:
                    return True
                return False
            else:
                return False
        return True
