#!/usr/bin/perl -w

#*******************************************************************************
#* Copyright (c) 2014-2015 Eclipse Foundation.
#* All rights reserved. This program and the accompanying materials
#* are made available under the terms of the Eclipse Public License v1.0
#* which accompanies this distribution, and is available at
#* http://www.eclipse.org/legal/epl-v10.html
#*
#* Contributors:
#*    Denis Roy (Eclipse Foundation) - Initial implementation
#*******************************************************************************/

# Use this script to process incoming Gerrit change emails, post to Bugzilla
$hostname = `hostname`;
$hostname =~ s/\n//;

my $basepath = "/path/to/tempdir";
my $logfile = $basepath . "/gerrit_to_bugzilla.log";
my $cgit_base = "http://git.eclipse.org/c/";

umask '002';



# Gerrit fields
my $message_type = "";
my $subject = "";
my $change_id = "";
my $change_url = "";
my $commit_id = "";
my $gerrit_project = "";
my $gerrit_branch = "";
my $bug_id = 0;



## subs
sub getLogHeader() {
        return getNow() . " " . $hostname . "[" . $$ . "] ";
}
1;


sub getNow() {
        my $rValue = "";
        # Build local date
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

        if (length($min) == 1) {
                $min = "0" . $min;
        }

        if (length($mon) == 1) {
                $mon = "0" . $mon;
        }

        if (length($mday) == 1) {
                $mday = "0" . $mday;
        }

        if (length($sec) == 1) {
                $sec = "0" . $sec;
        }

        $mon++;
        $year = $year + 1900;
        $rValue = sprintf("%s-%s-%s %s:%s:%s", $year, $mon, $mday, $hour, $min, $sec);
        return $rValue;

}
1;



## main
# Read incoming message.
while (<STDIN>) {
        if($_ =~ m/^X-Gerrit-MessageType: ([a-zA-Z0-9]+)/) {
                $message_type = $1;
        }
        if($_ =~ m/^Subject: (.*)/) {
                $subject = $1;
        }
        if($_ =~ m/^X-Gerrit-Change-Id: ([a-zA-Z0-9]+)/) {
                $change_id = $1;
        }
        if($_ =~ m/^X-Gerrit-ChangeURL: <(.*)>/) {
                $change_url = $1;
        }
        if($_ =~ m/^X-Gerrit-Commit: ([a-zA-Z0-9]+)/) {
                $commit_id = $1;
        }
        if($_ =~ m/^Gerrit-Project: ([a-zA-Z0-9\/\._-]+)/) {
                $gerrit_project = $1;
        }
        if($subject =~ m/([Bb]ug:?\s*#?)(\d+)/) {
                $bug_id = $2;
        }
        if($_ =~ m/^Gerrit-Branch: ([a-zA-Z0-9\/\._-]+)/) {
                $gerrit_branch = $1;
        }
}

if($bug_id > 0 && ($message_type eq "newchange" || $message_type eq "merged" || $message_type eq "newpatchset")) {

	# fabricate email_in
	my $bug_email = "From: genie\@eclipse.org\n";
	$bug_email .= "Subject: [Bug $bug_id]\n";
	$bug_email .= "\n";
	$bug_email .= "\@id = $bug_id\n";
	$bug_email .= "\@see_also = $change_url\n";
	
	if($message_type eq "newchange") {
		$bug_email .= "\n";
		$bug_email .= "New Gerrit change created: $change_url\n";
	}
	if($message_type eq "merged") {
		my $cgit_url = $cgit_base . $gerrit_project . ".git/commit/?id=" . $commit_id;
		$bug_email .= "\@see_also = $cgit_url\n";
		$bug_email .= "\n";
		$bug_email .= "Gerrit change $change_url was merged to [$gerrit_branch].\n";
		$bug_email .= "Commit: $cgit_url\n";
	}
	if($message_type eq "newpatchset") {
		# do nothing.  We just want to re-add the "see-also" field, which will do nothing if it's already there
	}

	$bug_email .= "";
	
	my $bugzilla_email_file	= $basepath . "/bugmail.bug$bug_id.$$.txt"; 
	open(FILE,">$bugzilla_email_file") || die("Cannot Open bugzilla email file");
	print FILE $bug_email;
	close(FILE);
}

open(FILE,">>$logfile") || die("Cannot Open File");
print FILE getLogHeader() . "Change [$change_id] type [$message_type] at url [$change_url] commit_id [$commit_id] with subject [$subject] and bug_id [$bug_id] for gerrit project [$gerrit_project]\n";
close(FILE);

exit 0;
