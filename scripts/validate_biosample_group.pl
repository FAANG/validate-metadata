#!/usr/bin/env perl
use strict;
use BioSD;

use Bio::Metadata::Loader::JSONRuleSetLoader;
use Bio::Metadata::Validate::Support::BioSDLookup;
use Bio::Metadata::Reporter::TextReporter;
use Bio::Metadata::Reporter::ExcelReporter;
use Bio::Metadata::Reporter::BasicReporter;
use Bio::Metadata::Validate::EntityValidator;
use Getopt::Long;
use Data::Dumper;
use Carp;
use List::Util qw(none);

my $rule_file     = undef;
my $verbose       = undef;
my $group_id      = undef;
my $output        = undef;
my $summary       = undef;
my $output_format = undef;

my @valid_output_mdoes = qw(text excel json);
my $output_format_string = join( '|', @valid_output_mdoes );

GetOptions(
  "rules=s"         => \$rule_file,
  "group_id=s"      => \$group_id,
  "verbose"         => \$verbose,
  "output=s"        => \$output,
  "output_format=s" => \$output_format,
  "summary"         => \$summary,
);

croak "-rules <file> is required"                unless $rule_file;
croak "-rules <file> must exist and be readable" unless -r $rule_file;
croak "-group_id <ID> is required"               unless $group_id;

croak
"no output requested, use -summary and/or -output <file> -output_format $output_format_string"
  unless ( $summary || $output );
croak "please specify -output_format $output_format_string"
  if ( $output && !$output_format );
croak "please specify -output <file>" if ( $output_format && !$output );
croak
"-output_format $output_format is invalid; should be one of $output_format_string"
  if ( $output_format && none { $_ eq $output_format } @valid_output_mdoes );

my $validator = create_validator( $rule_file, $verbose );
my $metadata = fetch_samples( $group_id, $verbose );

my (
  $entity_status,      $entity_outcomes, $attribute_status,
  $attribute_outcomes, $entity_rule_groups,
) = $validator->check_all($metadata);

print_summary( $entity_status, $attribute_status ) if ($summary);

write_output(
  $output,
  $output_format,
  {
    entities           => $metadata,
    entity_status      => $entity_status,
    entity_outcomes    => $entity_outcomes,
    attribute_status   => $attribute_status,
    attribute_outcomes => $attribute_outcomes,
  }
) if ($output);

sub fetch_samples {
  my ( $group_id, $verbose ) = @_;

  my $biosd = Bio::Metadata::Validate::Support::BioSDLookup->new();
  print 'Fetching group ' . $group_id . $/ if ($verbose);

  my $metadata = $biosd->fetch_group_samples($group_id);
  croak "-group_id $group_id did not match a group in BioSamples"
    unless ($metadata);
  croak "-group_id $group_id matched an empty group in BioSamples"
    unless (@$metadata);

  print 'Fetched '
    . scalar(@$metadata)
    . ' samples from BioSamples for '
    . $group_id
    . $/
    if ($verbose);

  return $metadata;
}

sub create_validator {
  my ( $rule_file, $verbose ) = @_;

  my $loader = Bio::Metadata::Loader::JSONRuleSetLoader->new();
  print "Attempting to load $rule_file$/" if $verbose;
  my $rule_set = $loader->load($rule_file);
  print 'Loaded ' . $rule_set->name . $/ if $verbose;

  my $validator =
    Bio::Metadata::Validate::EntityValidator->new( rule_set => $rule_set );

  return $validator;
}

sub print_summary {
  my ( $entity_status, $attribute_status ) = @_;

  for ( [ 'samples', $entity_status ], [ 'attributes', $attribute_status ] ) {
    my $title       = $_->[0];
    my $status_hash = $_->[1];

    my $total = scalar( keys %$status_hash );
    my %status_counts;
    map { $status_counts{$_}++ } values %$status_hash;

    print "$total $title - ";
    print join( '; ',
      map { $_ . '(' . $status_counts{$_} . ')' } sort keys %status_counts );
    print $/;
  }
}

sub write_output {
  my ( $output, $output_format, $validator_output ) = @_;

  my $reporter;
  if ( $output_format eq 'text' ) {
    $reporter = Bio::Metadata::Reporter::TextReporter->new();
  }
  elsif ( $output_format eq 'excel'){
    $reporter = Bio::Metadata::Reporter::ExcelReporter->new();
  }
  elsif ($output_format eq 'json'){
    $reporter = Bio::Metadata::Reporter::BasicReporter->new();
  }

  if ( $output eq 'stdout' || $output eq '-' ) {
    $reporter->file_handle( \*STDOUT );
  }
  else {
    $reporter->file_path($output);
  }

  $reporter->report(
    entities           => $metadata,
    entity_status      => $entity_status,
    entity_outcomes    => $entity_outcomes,
    attribute_status   => $attribute_status,
    attribute_outcomes => $attribute_outcomes,
  );
}
