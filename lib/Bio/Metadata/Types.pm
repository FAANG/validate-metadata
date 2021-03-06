
=head1 LICENSE
   Copyright 2015 EMBL - European Bioinformatics Institute
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
     http://www.apache.org/licenses/LICENSE-2.0
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
=cut

package Bio::Metadata::Types;

use strict;
use warnings;
use Carp;
use Moose::Util::TypeConstraints;
use JSON::PP::Boolean;

enum 'Bio::Metadata::Rules::Rule::TypeEnum', [
  qw(text number enum ontology_uri ontology_text ontology_id uri_value date
    relationship ncbi_taxon ontology_attr_name faang_breed subid)
];
enum 'Bio::Metadata::Rules::Rule::MandatoryEnum',
  [qw(mandatory recommended optional)];

our @OUTCOME_VALUES = qw(pass error warning);

enum 'Bio::Metadata::Validate::OutcomeEnum', \@OUTCOME_VALUES;

role_type 'Bio::Metadata::Validate::AttributeValidatorRole';
role_type 'Bio::Metadata::Loader::JSONLoaderRole';
role_type 'Bio::Metadata::Loader::RuleSetLoaderRole';
role_type 'Bio::Metadata::Consistency::ConsistencyCheckRole';

class_type 'JSON::PP::Boolean';

#hack to allow JSON parser bools to be used as Bool
union('Bio::Metadata::FlexiBool',[qw(JSON::PP::Boolean Bool)]);

#attribute
class_type 'Bio::Metadata::Attribute';

coerce 'Bio::Metadata::Attribute' => from 'HashRef' =>
  via { Bio::Metadata::Attribute->new($_); };

subtype 'Bio::Metadata::AttributeArrayRef' => as
  'ArrayRef[Bio::Metadata::Attribute]';

coerce 'Bio::Metadata::AttributeArrayRef' => from 'ArrayRef[HashRef]' => via {
  [ map { Bio::Metadata::Attribute->new($_) } @$_ ];
},
  from 'Bio::Metadata::Attribute' => via {
  [$_];
  },
  from 'HashRef' => via {
  [ Bio::Metadata::Attribute->new($_) ];
  };

#rule set
class_type 'Bio::Metadata::Rules::RuleSet';
coerce 'Bio::Metadata::Rules::RuleSet' => from 'HashRef' =>
  via { Bio::Metadata::Rules::RuleSet->new($_) };

subtype 'Bio::Metadata::Rules::RuleSetArrayRef' => as
  'ArrayRef[Bio::Metadata::Rules::RuleSet]';

coerce 'Bio::Metadata::Rules::RuleSetArrayRef' => from 'ArrayRef[HashRef]' =>
  via {
  [ map { Bio::Metadata::Rules::RuleSet->new($_) } @$_ ];
  },
  from
  'Bio::Metadata::Rules::RuleSet' => via { [$_] },
  from 'HashRef' => via { [ Bio::Metadata::Rules::RuleSet->new($_) ] };

#entity
class_type 'Bio::Metadata::Entity';

coerce 'Bio::Metadata::Entity' => from 'HashRef' =>
  via { Bio::Metadata::Entity->new($_); };

subtype 'Bio::Metadata::EntityArrayRef' => as 'ArrayRef[Bio::Metadata::Entity]';

coerce 'Bio::Metadata::EntityArrayRef' => from 'ArrayRef[HashRef]' => via {
  [ map { Bio::Metadata::Entity->new($_) } @$_ ];
},
  from 'Bio::Metadata::Entity' => via {
  [$_];
  },
  from 'HashRef' => via {
  [ Bio::Metadata::Entity->new($_) ];
  };

#rule
class_type 'Bio::Metadata::Rules::Rule';
coerce 'Bio::Metadata::Rules::Rule' => from 'HashRef' =>
  via { Bio::Metadata::Rules::Rule->new($_); };

subtype 'Bio::Metadata::Rules::RuleArrayRef' => as
  'ArrayRef[Bio::Metadata::Rules::Rule]';

coerce 'Bio::Metadata::Rules::RuleArrayRef' => from 'ArrayRef[HashRef]' => via {
  [ map { Bio::Metadata::Rules::Rule->new($_) } @$_ ];
},
  from 'Bio::Metadata::Rules::Rule' => via {
  [$_];
  },
  from 'HashRef' => via {
  [ Bio::Metadata::Rules::Rule->new($_) ];
  };

#rule group
class_type 'Bio::Metadata::Rules::RuleGroup';
coerce 'Bio::Metadata::Rules::RuleGroup' => from 'HashRef' =>
  via { Bio::Metadata::Rules::RuleGroup->new($_); };

subtype 'Bio::Metadata::Rules::RuleGroupArrayRef' => as
  'ArrayRef[Bio::Metadata::Rules::RuleGroup]';

coerce 'Bio::Metadata::Rules::RuleGroupArrayRef' => from 'ArrayRef[HashRef]' =>
  via {
  [ map { Bio::Metadata::Rules::RuleGroup->new($_) } @$_ ];
  },
  from 'Bio::Metadata::Rules::RuleGroup' => via {
  [$_];
  },
  from 'HashRef' => via {
  [ Bio::Metadata::Rules::RuleGroup->new($_) ];
  };

#condition
class_type 'Bio::Metadata::Rules::Condition';
coerce 'Bio::Metadata::Rules::Condition' => from
  'HashRef' => via { Bio::Metadata::Rules::Condition->new($_); },
  from 'Str ' =>
  via { Bio::Metadata::Rules::Condition->new( dpath_condition => $_ ); };

subtype 'Bio::Metadata::Rules::ConditionArrayRef' => as
  'ArrayRef[Bio::Metadata::Rules::Condition]';

coerce 'Bio::Metadata::Rules::ConditionArrayRef' => from 'ArrayRef[HashRef]' =>
  via {
  [ map { Bio::Metadata::Rules::Condition->new($_) } @$_ ];
  },
  from 'Bio::Metadata::Rules::Condition' => via {
  [$_];
  },
  from 'HashRef' => via {
  [ Bio::Metadata::Rules::Condition->new($_) ];
  },
  from 'Str' =>
  via { [ Bio::Metadata::Rules::Condition->new( dpath_condition => $_ ) ] };

#PermittedTerm
class_type 'Bio::Metadata::Rules::PermittedTerm';

coerce 'Bio::Metadata::Rules::PermittedTerm' => from 'HashRef' =>
  via { Bio::Metadata::Rules::PermittedTerm->new($_); };
subtype 'Bio::Metadata::Rules::PermittedTermArrayRef' => as
  'ArrayRef[Bio::Metadata::Rules::PermittedTerm]';
coerce 'Bio::Metadata::Rules::PermittedTermArrayRef' => from
  'ArrayRef[HashRef]'                                => via {
  [ map { Bio::Metadata::Rules::PermittedTerm->new($_) } @$_ ];
  },
  from 'Bio::Metadata::Rules::PermittedTerm' => via {
  [$_];
  },
  from 'HashRef' => via {
  [ Bio::Metadata::Rules::PermittedTerm->new($_) ];
  };

#RuleImport
class_type 'Bio::Metadata::Rules::RuleImport';
coerce 'Bio::Metadata::Rules::RuleImport' => from 'HashRef' =>
  via { Bio::Metadata::Rules::RuleImport->new($_); };
subtype 'Bio::Metadata::Rules::RuleImportArrayRef' => as
  'ArrayRef[Bio::Metadata::Rules::RuleImport]';
coerce 'Bio::Metadata::Rules::RuleImportArrayRef' => from
  'ArrayRef[HashRef]'                             => via {
  [ map { Bio::Metadata::Rules::RuleImport->new($_) } @$_ ];
  },
  from 'Bio::Metadata::Rules::RuleImport' => via {
  [$_];
  },
  from 'HashRef' => via {
  [ Bio::Metadata::Rules::RuleImport->new($_) ];
  };

#validation outcome
class_type 'Bio::Metadata::Validate::ValidationOutcome';
coerce 'Bio::Metadata::Validate::ValidationOutcome' => from 'HashRef' =>
  via { Bio::Metadata::Validate::ValidationOutcome->new($_); };

subtype 'Bio::Metadata::Validate::ValidationOutcomeArrayRef' => as
  'ArrayRef[Bio::Metadata::Validate::ValidationOutcome]';

coerce 'Bio::Metadata::Validate::ValidationOutcomeArrayRef' => from
  'ArrayRef[HashRef]'                                       => via {
  [ map { Bio::Metadata::Validate::ValidationOutcome->new($_) } @$_ ];
  },
  from 'Bio::Metadata::Validate::ValidationOutcome' => via {
  [$_];
  },
  from 'HashRef' => via {
  [ Bio::Metadata::Validate::ValidationOutcome->new($_) ];
  };

class_type 'Bio::Metadata::Validate::Support::OlsLookup';

1;
