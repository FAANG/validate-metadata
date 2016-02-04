#!/usr/bin/env bash
pushd `dirname $0` > /dev/null
SCRIPTPATH=`pwd`
popd > /dev/null

curl -X POST -F "format=json;rule_set_name=test_rules;metadata_file=$SCRIPTPATH/../t/data/test_data.json" http://127.0.0.1:3000/validate_upload