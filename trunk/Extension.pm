# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the HiddenNameAndMail Bugzilla Extension.
#
# The Initial Developer of the Original Code is Ali Ustek
# Portions created by the Initial Developer are Copyright (C) 2010 the
# Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Ali Ustek <aliustek@gmail.com>

package Bugzilla::Extension::HiddenNameAndMail;
use strict;
use base qw(Bugzilla::Extension);

use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Config::Common;

# This code for this is in ./extensions/HiddenNameAndMail/lib/Util.pm
use Bugzilla::Extension::HiddenNameAndMail::Util;

our $VERSION = '0.01';

BEGIN { 
   *Bugzilla::User::hidden_email = \&hidden_email;
   *Bugzilla::User::hidden_name = \&hidden_name;
   *Bugzilla::User::set_hidden_email = \&set_hidden_email;
   *Bugzilla::User::set_hidden_name = \&set_hidden_name;
   *Bugzilla::User::is_available_hidden_email = \&is_available_hidden_email;
   *Bugzilla::User::hiddenMail_to_id = \&hiddenMail_to_id;
}

###########################
# Database & Installation #
###########################

sub install_update_db {
    my $dbh = Bugzilla->dbh;
    $dbh->bz_add_column('profiles', 'hidden_name', 
                        {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"});

    $dbh->bz_add_column('profiles', 'hidden_email', 
                        {TYPE => 'varchar(255)', NOTNULL => 1, DEFAULT => "''"});
}

###########
# Bugmail #
###########

sub mailer_before_send {
    my ($self, $args) = @_;
    
    my $email = $args->{email};
    my $to = $email->header('To');
    my $hidden_mail = (new Bugzilla::User({ name => $to }))->hidden_email;
    $email->header_set('To', $hidden_mail ? $hidden_mail : $to);
}

###########
# Objects #
###########

sub object_columns {
    my ($self, $args) = @_;
    my ($class, $columns) = @$args{qw(class columns)};

    if ($class->isa('Bugzilla::User')) {
        push(@$columns, 'profiles.hidden_email');
        push(@$columns, 'profiles.hidden_name');
    }
}

sub object_update_columns {
    my ($self, $args) = @_;
    my ($object, $columns) = @$args{qw(object columns)};

    if ($object->isa('Bugzilla::User')) {
        push(@$columns, 'hidden_email');
        push(@$columns, 'hidden_name');
    }
}

sub object_validators {
    my ($self, $args) = @_;
    my ($class, $validators) = @$args{qw(class validators)};

    if ($class->isa('Bugzilla::User')) {
        $validators->{hidden_email} = \&_check_hidden_email_for_creation;
        $validators->{hidden_name} = \&_check_hidden_name_for_creation;
    }
}

##########
# Config #
##########

sub config_modify_panels {
    my ($self, $args) = @_;
    my $panels = $args->{panels};
    my $auth_params = $panels->{'auth'}->{params};
    
    push(@$auth_params, { name => 'hidden_email_regexp',
                          type => 't',
                          default => 'q:^[\\w\\.\\+\\-=]+@[\\w\\.\\-]+\\.[\\w\\-]+$:',
                          checker => \&check_regexp });
                          
    push(@$auth_params, { name => 'hidden_email_regexp_desc',
                          type => 'l',
                          default => 'A legal address must contain exactly one \'@\', and at least, ' .
                                     'one \'.\' after the @.'
                        });
}

#######################
# User Object Methods #
#######################

sub _check_hidden_email_for_creation {
    my ($invocant, $hiddenemail) = @_;
    $hiddenemail = trim($hiddenemail);
    if ($hiddenemail ne '') {
        _validate_hidden_email_syntax($hiddenemail)
        || ThrowUserError('illegal_hidden_email_address', { addr => $hiddenemail });
    }
    
    # Check the name if it's a new user, or if we're changing the hidden email
    if (!ref($invocant) || $invocant->hidden_email ne $hiddenemail) {
        is_available_hidden_email($hiddenemail) 
            || ThrowUserError('hidden_email_exists', { email => $hiddenemail });
    }

    # Check the name if it's a new user, or if we're changing the name.
    if (!ref($invocant) || $invocant->login ne $hiddenemail) {
        is_available_username($hiddenemail) 
            || ThrowUserError('account_exists', { email => $hiddenemail });
    }
    return $hiddenemail;
}

sub _validate_hidden_email_syntax {
    my ($addr) = @_;
    if($addr eq ''){
        trick_taint($_[0]);
        return 1;
    }
    my $match = Bugzilla->params->{'hidden_email_regexp'};
    my $ret = ($addr =~ /$match/ && $addr !~ /[\\\(\)<>&,;:"\[\] \t\r\n]/);
    if ($ret) {
        # We assume these checks to suffice to consider the address untainted.
        trick_taint($_[0]);
    }
    return $ret ? 1 : 0;
}

sub _check_hidden_name_for_creation { return trim($_[1]) || ''; }

sub set_hidden_email { $_[0]->set('hidden_email', $_[1]); }
sub set_hidden_name { $_[0]->set('hidden_name', $_[1]); }
sub hidden_email { $_[0]->{hidden_email}; }
sub hidden_name { $_[0]->{hidden_name}; }

sub is_available_hidden_email {
    my ($hidden_email) = @_;
    trick_taint($hidden_email);
    my @hiddenemail = Bugzilla->dbh->selectrow_array("SELECT hidden_email FROM profiles WHERE hidden_email='$hidden_email'");
    
    #if hiddenemail was renturned then return false
    if ($hiddenemail[0]) {
        return 0;
    }

    return 1;
}

sub hiddenMail_to_id {
    my ($hidden_email, $throw_error) = @_;
    my $dbh = Bugzilla->dbh;
    # No need to validate $hidden_email -- it will be used by the following SELECT
    # statement only, so it's safe to simply trick_taint.
    trick_taint($hidden_email);
    my $user_id = $dbh->selectrow_array("SELECT userid FROM profiles WHERE " .
                                        $dbh->sql_istrcmp('hidden_email', '?'),
                                        undef, $hidden_email);
    if ($user_id) {
        return $user_id;
    } elsif ($throw_error) {
        ThrowUserError('invalid_username', { name => $hidden_email });
    } else {
        return 0;
    }
}

__PACKAGE__->NAME;

__END__
=head1 NAME

Bugzilla::Extension::HiddenNameAndMail - Object for a Bugzilla HiddenNameAndMail extension

=head1 DESCRIPTION
This package will create hidden name and email for Bugzilla users

=head2 Custom Added Function

=over

=item C<hidden_email>
Returns the hidden email for this user.
=item C<hidden_name>
Returns the hidden name for this user.
=item C<is_available_hidden_email>
==over

=item B<Description>

Check to see if the email is used in hidden email.

=item B<Params>

=over

=item C<$hidden_email> - Email to be checked

=back

=item B<Returns>

Returns a boolean indicating whether or not the supplied email is already taken in Bugzilla.

=back

=back

=item C<hiddenMail_to_id($login, $throw_error)>

Takes a hiddend name of a Bugzilla user and changes that into a numeric
ID for that user. This ID can then be passed to Bugzilla::User::new to
create a new user.

If no valid user exists with that hidden name, then the function returns 0.
However, if $throw_error is set, the function will throw a user error
instead of returning.

This function can also be used when you want to just find out the userid
of a user, but you don't want the full weight of Bugzilla::User.

However, consider using a Bugzilla::User object instead of this function
if you need more information about the user than just their ID.

=back

=head1 SEE ALSO

L<Bugzilla::User>
