# Copyright 2015 European Molecular Biology Laboratory - European Bioinformatics Institute
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
package Bio::Metadata::Rules::Rule;

use strict;
use warnings;

use Moose;
use namespace::autoclean;
use Bio::Metadata::Types;
use Bio::Metadata::Rules::PermittedTerm;

has 'name' => ( is => 'rw', isa => 'Str' );
has 'description' => ( is => 'rw', isa => 'Str' );
has 'type' => ( is => 'rw', isa => 'Bio::Metadata::Rules::Rule::TypeEnum', required => 1 );
has 'mandatory' =>
  ( is => 'rw', isa => 'Bio::Metadata::Rules::Rule::MandatoryEnum' );
has 'allow_multiple' => ( is => 'rw', isa => 'Bio::Metadata::FlexiBool', default => 0 );
has 'valid_values' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    handles => {
        all_valid_values   => 'elements',
        add_valid_values   => 'push',
        count_valid_values => 'count',
        get_valid_values   => 'get',
        find_valid_value   => 'first',
        join_valid_values  => 'join',
    },
    default => sub { [] },
);
has 'valid_units' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    handles => {
        all_valid_units   => 'elements',
        add_valid_units   => 'push',
        count_valid_units => 'count',
        get_valid_units   => 'get',
        find_valid_unit   => 'first',
        join_valid_units  => 'join',
    },
    default => sub { [] },
);
has 'valid_terms' => (
  traits => ['Array'],
  is => 'rw',
  isa => 'Bio::Metadata::Rules::PermittedTermArrayRef',
  handles => {
    all_valid_terms => 'elements',
    add_valid_terms => 'push',
    count_valid_terms => 'count',
    get_valid_term => 'get',
    find_valid_term => 'first',
  },
  coerce => 1,
  default => sub {[]},
);

has 'condition' =>
  ( is => 'rw', isa => 'Bio::Metadata::Rules::Condition', coerce => 1 );

sub to_hash {
    my ($self) = @_;

    my @vv = $self->all_valid_values;
    my @vu = $self->all_valid_units;
    my @vt = map { $_->to_hash } $self->all_valid_terms;
  
  
    my $condition = $self->condition ? $self->condition->to_hash : undef;

    return {
        name           => $self->name,
        description    => $self->description,
        type           => $self->type,
        mandatory      => $self->mandatory,
        allow_multiple => $self->allow_multiple,
        condition      => $condition,
        valid_values   => \@vv,
        valid_units    => \@vu,
        valid_terms    => \@vt
    };
}

__PACKAGE__->meta->make_immutable;
1;
