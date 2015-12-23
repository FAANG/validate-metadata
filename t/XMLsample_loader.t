#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Bio::Metadata::Loader::XMLSampleLoader;
use Data::Dumper;
use Test::More;

my $data_dir = "$Bin/data";

my $loader = Bio::Metadata::Loader::XMLSampleLoader->new();

my $o=$loader->load("$data_dir/sample_good.xml");

isa_ok($o, "Bio::Metadata::Entity");

done_testing();