# Copyright 2016 European Molecular Biology Laboratory - European Bioinformatics Institute
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
package Bio::Metadata::ENA::RUNValidation;

use Moose;
use namespace::autoclean;
use Bio::Metadata::Rules::RuleSet;
use Bio::Metadata::Rules::Rule;
use Bio::Metadata::Validate::ValidationOutcome;
use Bio::Metadata::Validate::EntityValidator;

has 'run_rule_set' => (
  is      => 'ro',
  isa     => 'Bio::Metadata::Rules::RuleSet',
  coerce  => 1,
  default => sub {
    {
      name        => 'Run XML section - run',
      rule_groups => [
        {
          name  => 'Run rules',
          rules => [
            {
              name      => 'alias',
              mandatory => 'mandatory',
              type      => 'text'
            },
            {
              name      => 'run_center',
              mandatory => 'mandatory',
              type      => 'text'
            },
            {
              name      => 'run_date',
              mandatory => 'optional',
              type      => 'text'
            },
            {
              name      => 'EXPERIMENT_REF',
              mandatory => 'mandatory',
              type      => 'text'
            },
            {
              name      => 'filename',
              mandatory => 'mandatory',
              type      => 'text'
            },
            {
              name      => 'filetype',
              mandatory => 'mandatory',
              type      => 'text'
            },
            {
              name      => 'checksum_method',
              mandatory => 'mandatory',
              type      => 'text'
            },
            {
              name      => 'checksum',
              mandatory => 'mandatory',
              type      => 'text'
            },
                        {
              name      => 'filename_pair',
              mandatory => 'optional',
              type      => 'text'
            },
            {
              name      => 'filetype_pair',
              mandatory => 'optional',
              type      => 'text'
            },
            {
              name      => 'checksum_method_pair',
              mandatory => 'optional',
              type      => 'text'
            },
            {
              name      => 'checksum_pair',
              mandatory => 'optional',
              type      => 'text'
            },
          ]
        },
      ]
    };
  }
);

my @filetypes = qw/sra srf sff fastq fasta tab 454_native  454_native_seq  454_native_qual Helicos_native  Illumina_native Illumina_native_seq Illumina_native_prb Illumina_native_int Illumina_native_qseq  Illumina_native_scarf SOLiD_native  SOLiD_native_csfasta  SOLiD_native_qual PacBio_HDF5 bam cram  CompleteGenomics_native OxfordNanopore_native/;
my %filetypes;
foreach (@filetypes){
  $filetypes{$_} = 1;
}

sub validate_run {
  my ( $self, $run_entries ) = @_;

  my %blocks;
  for my $run_entity (@$run_entries) {
    $blocks{ $run_entity->id } //= [];
    push @{ $blocks{ $run_entity->id } }, $run_entity;
  }

  my @errors;
  push @errors,
    $self->validate_section( \%blocks, $self->run_rule_set);

  return \@errors;
}

sub validate_section {
  my ( $self, $blocks, $rule_set) = @_;

  my @rows = keys(%$blocks);

  if ( scalar(@rows) == 0 ) {
    return Bio::Metadata::Validate::ValidationOutcome->new(
      outcome => 'error',
      message => "At least one run required",
      rule =>
        Bio::Metadata::Rules::Rule->new( name => "run", type => 'text' ),
    );
  }

  my $v = Bio::Metadata::Validate::EntityValidator->new( rule_set => $rule_set );

  my @errors;
  my @tmpErrors;
  my %errors;
  foreach my $row (@rows){
    my $entities = $blocks->{$row} || [];
    for my $e (@$entities) {
      my ( $outcome_overall, $validation_outcomes ) = $v->check($e);
      push @tmpErrors, grep { $_->outcome ne 'pass' } @$validation_outcomes;
      my @limitedErrors = &checkLimitedValues($e);
      foreach my $limitedError(@limitedErrors){
        $errors{$limitedError}++;
      } 
    }
  }
  my %hash;
  foreach my $validationOutcome(@tmpErrors){
    my $outcome = $validationOutcome->outcome;
    my $message = $validationOutcome->message;
    my $rule_name = $validationOutcome->rule->name;
    my $type = $validationOutcome->rule->type;
    my $key = "outcome($outcome)-message($message)-ruleName($rule_name)-type($type)";
    $hash{$key}++;
  }
  foreach my $key(keys %hash){
    if ($key=~/^outcome\((.+)\)-message\((.+)\)-ruleName\((.+)\)-type\((.+)\)$/){
      push @errors, Bio::Metadata::Validate::ValidationOutcome->new(
        outcome => $1,
        message => "$2: occuring $hash{$key} times",
        rule => Bio::Metadata::Rules::Rule->new(name => $3, type => $4)
      );
    }
  }
  foreach my $limitedError(keys %errors){
    push @errors, Bio::Metadata::Validate::ValidationOutcome->new(
      outcome => 'error',
      message => "$limitedError: occuring $errors{$limitedError} times",
      rule =>
        Bio::Metadata::Rules::Rule->new( name => "run", type => 'text' ),
    );
  }
  return @errors;
}

sub checkLimitedValues(){
  my $entity = $_[0];
  my @errorMsgs;
  foreach my $attr(@{$entity->attributes}){
    my $value = $attr->value;
    if($attr->name eq "checksum_method"){
      unless ($value eq "MD5" || $value eq "SHA-256"){
        push @errorMsgs,"Wrong checksum_method value \"$value\", which can only be either MD5 or SHA-256 according to ENA rule";
      }
    }
    if($attr->name eq "filetype"){
      push @errorMsgs, "Wrong filetype value \"$value\", only could be one of @filetypes" unless (exists $filetypes{$value});
    }
    if($attr->name eq "checksum_method_pair"){
      unless ($value eq "MD5" || $value eq "SHA-256" || $value eq ""){
        push @errorMsgs,"Wrong checksum_method_pair value \"$value\", which can only be either MD5 or SHA-256 according to ENA rule";
      }
    }
    if($attr->name eq "filetype_pair"){
      push @errorMsgs, "Wrong filetype_pair value \"$value\", only could be one of @filetypes" unless (exists $filetypes{$value} || $value eq "");
    }
    if($attr->name eq "run_date"){
      my $err = &checkDate($value);
      push @errorMsgs, $err unless ((length $err) == 0);
    }
  }
  return @errorMsgs;
}

sub checkDate(){
  my $isoStr = $_[0];
  unless ($isoStr =~/^\d.+\d$/){
    return "Error: wrong date value $isoStr";
  }
  #already xs:dateTime format
  if ($isoStr =~/^\d{4,4}-\d{2,2}-\d{2,2}T\d{2,2}:\d{2,2}:\d{2,2}$/){
    return "";
  }
  my @elem = split ("-",$isoStr);
  my $len = scalar @elem;
  return "Input date not in the YYYY-MM-DD or YYYY-MM or YYYY format" if ($len > 3);
  unless ($elem[0]=~/^\d{4,4}$/){
    return "Error: unrecognized year value $elem[0]";
  }
  if ($len > 1){
    unless ($elem[1]=~/^\d{2,2}$/){
      return "Error: unrecognized month value $elem[1]";
    }
  }
  if ($len == 3){
    unless ($elem[2]=~/^\d{2,2}$/){
      return "Error: unrecognized day value $elem[2]";
    }
  }
  return "";
}


__PACKAGE__->meta->make_immutable;
1;