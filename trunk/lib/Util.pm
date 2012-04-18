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

package Bugzilla::Extension::HiddenNameAndMail::Util;
use strict;
use base qw(Exporter);
our @EXPORT = qw(validate_hidden_email_syntax);

sub validate_hidden_email_syntax {
    my ($addr) = @_;
    if($addr eq ''){
        trick_taint($_[0]);
        return 1;
    }
    my $match = Bugzilla->params->{'emailregexp'};
    my $ret = ($addr =~ /$match/ && $addr !~ /[\\\(\)<>&,;:"\[\] \t\r\n]/);
    if ($ret) {
        # We assume these checks to suffice to consider the address untainted.
        trick_taint($_[0]);
    }
    return $ret ? 1 : 0;
}

1;