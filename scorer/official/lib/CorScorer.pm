package CorScorer;

# Copyright (C) 2009-2010, Emili Sapena esapena <at> lsi.upc.edu
# 
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version. This program is distributed in the hope that
# it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

use strict;
use Algorithm::Munkres;

our $VERSION = '1.04';

# 1.04	Some output corrections in BLANC functions. Changed package name to "Scorer"
# 1.03	Detects mentions that start in a document but do not end
# 1.02	Corrected Bcub bug. It fails when the key file does not have any mention



# global variables
my $VERBOSE = 1;
my $HEAD_COLUMN = 8;
my $RESPONSE_COLUMN = -1;
my $KEY_COLUMN = -1;


# Score. Scores the results of a coreference resultion system
# Input: Metric, keys file, response file, [name]
#        Metric: the metric desired to evaluate:
#                muc: MUCScorer (Vilain et al, 1995)
#                bcub: B-Cubed (Bagga and Baldwin
#                ceafm: CEAF (Luo et al, 2005) using mention-based similarity
#                ceafe: CEAF (Luo et al, 2005) using entity-based similarity
#        keys file: file with expected coreference chains in SemEval format
#        response file: file with output of corefrence system (SemEval format)
#        name: [optional] the name of the document to score. If name is not
#              given, all the documents in the dataset will be scored.
#
# Output: an array with numerators and denominators of recall and precision
#         (recall_num, recall_den, precision_num, precision_den)
#
#   Final scores:
# Recall = recall_num / recall_den
# Precision = precision_num / precision_den
# F1 = 2 * Recall * Precision / (Recall + Precision)
sub Score
{
	my ($metric, $kFile, $rFile, $name) = @_;
	
	if (lc($metric) eq 'blanc') {
		return ScoreBLANC($kFile, $rFile, $name);
	}
	
	my %idenTotals = (recallDen => 0, recallNum => 0, precisionDen => 0, precisionNum => 0);
	my ($acumNR, $acumDR, $acumNP, $acumDP) = (0,0,0,0);
	
	if (defined($name) && $name ne 'none') {
		print "$name:\n" if ($VERBOSE);
		my $keys = GetCoreference($kFile, $KEY_COLUMN, $name);
		my $response = GetCoreference($rFile, $RESPONSE_COLUMN, $name);
		my ($keyChains, $responseChains) = IdentifMentions($keys, $response, \%idenTotals);
		($acumNR, $acumDR, $acumNP, $acumDP) = Eval($metric, $keyChains, $responseChains);
	}
	else {
		my $kIndexNames = GetFileNames($kFile);
		my $rIndexNames = GetFileNames($rFile);
		
		$VERBOSE = 0 if ($name eq 'none');
		foreach my $iname (keys(%{$kIndexNames})) {
			my $keys = GetCoreference($kFile, $KEY_COLUMN, $iname, $kIndexNames->{$iname});
			my $response = GetCoreference($rFile, $RESPONSE_COLUMN, $iname, $rIndexNames->{$iname});

			print "$iname:\n" if ($VERBOSE);
			my ($keyChains, $responseChains) = IdentifMentions($keys, $response, \%idenTotals);
			my ($nr, $dr, $np, $dp) = Eval($metric, $keyChains, $responseChains);
		
			$acumNR += $nr;
			$acumDR += $dr;
			$acumNP += $np;
			$acumDP += $dp;
		}
	}
	
	if ($VERBOSE || $name eq 'none') {
		print "\n====== TOTALS =======\n";
		print "Identification of Mentions: ";
		ShowRPF($idenTotals{recallNum}, $idenTotals{recallDen}, $idenTotals{precisionNum},
				  $idenTotals{precisionDen});
		print "Coreference: ";
		ShowRPF($acumNR, $acumDR, $acumNP, $acumDP);
	}
	
	return ($acumNR, $acumDR, $acumNP, $acumDP);
}

sub ScoreBLANC
{
	my ($kFile, $rFile, $name) = @_;
	my ($acumNRa, $acumDRa, $acumNPa, $acumDPa) = (0,0,0,0);
	my ($acumNRr, $acumDRr, $acumNPr, $acumDPr) = (0,0,0,0);
	my %idenTotals = (recallDen => 0, recallNum => 0, precisionDen => 0, precisionNum => 0);
	
	if (defined($name) && $name ne 'none') {
		print "$name:\n" if ($VERBOSE);
		my $keys = GetCoreference($kFile, $KEY_COLUMN, $name);
		my $response = GetCoreference($rFile, $RESPONSE_COLUMN, $name);
		my ($keyChains, $responseChains) = IdentifMentions($keys, $response, \%idenTotals);
		($acumNRa, $acumDRa, $acumNPa, $acumDPa, $acumNRr, $acumDRr, $acumNPr, $acumDPr) = BLANC($keyChains, $responseChains);
	}
	else {
		my $kIndexNames = GetFileNames($kFile);
		my $rIndexNames = GetFileNames($rFile);
		
		$VERBOSE = 0 if ($name eq 'none');
		foreach my $iname (keys(%{$kIndexNames})) {
			my $keys = GetCoreference($kFile, $KEY_COLUMN, $iname, $kIndexNames->{$iname});
			my $response = GetCoreference($rFile, $RESPONSE_COLUMN, $iname, $rIndexNames->{$iname});

			print "$name:\n" if ($VERBOSE);
			my ($keyChains, $responseChains) = IdentifMentions($keys, $response, \%idenTotals);
			my ($nra, $dra, $npa, $dpa, $nrr, $drr, $npr, $dpr) = BLANC($keyChains, $responseChains);
			
			$acumNRa += $nra;
			$acumDRa += $dra;
			$acumNPa += $npa;
			$acumDPa += $dpa;
			$acumNRr += $nrr;
			$acumDRr += $drr;
			$acumNPr += $npr;
			$acumDPr += $dpr;
		}
	}
	
	if ($VERBOSE || $name eq 'none') {
		print "\n====== TOTALS =======\n";
		print "Identification of Mentions: ";
		ShowRPF($idenTotals{recallNum}, $idenTotals{recallDen}, $idenTotals{precisionNum},
				  $idenTotals{precisionDen});
		print "\nCoreference:\n";
		print "Coreference links: ";
		ShowRPF($acumNRa, $acumDRa, $acumNPa, $acumDPa);
		print "Non-coreference links: ";
		ShowRPF($acumNRr, $acumDRr, $acumNPr, $acumDPr);
		print "BLANC: ";
		
		my $Ra = ($acumDRa) ? $acumNRa/$acumDRa : -1;
		my $Rr = ($acumDRr) ? $acumNRr/$acumDRr : -1;
		my $Pa = ($acumDPa) ? $acumNPa/$acumDPa : 0;
		my $Pr = ($acumDPr) ? $acumNPr/$acumDPr : 0;
		
		my $R = ($Ra + $Rr) / 2;
		my $P = ($Pa + $Pr) / 2;
		
		my $Fa = ($Pa + $Ra) ? 2 * $Pa * $Ra / ($Pa + $Ra) : 0;
		my $Fr = ($Pr + $Rr) ? 2 * $Pr * $Rr / ($Pr + $Rr) : 0;
		
		my $f1 = ($Fa + $Fr) / 2;
		
		if ($Ra == -1 && $Rr == -1) {
			$R = 0;
			$P = 0;
			$f1 = 0;
		}
		elsif ($Ra == -1) {
			$R = $Rr;
			$P = $Pr;
			$f1 = $Fr;
		}
		elsif ($Rr == -1) {
			$R = $Ra;
			$P = $Pa;
			$f1 = $Fa;
		}

		ShowRPF($R, 1, $P, 1, $f1);
	}
	
	return ($acumNRa, $acumDRa, $acumNPa, $acumDPa, $acumNRr, $acumDRr, $acumNPr, $acumDPr);
}


sub GetIndex
{
	my ($ind, $i) = @_;
	if (!defined($ind->{$i})) {
		my $n = $ind->{nexti} || 0;
		$ind->{$i} = $n;
		$n++;
		$ind->{nexti} = $n;
	}
	
	return $ind->{$i};
}

# Get the coreference information from column $column of the file $file
# If $name is defined, only keys between "#begin document $name" and
# "#end file $name" are taken.
# The output is an array of entites, where each entity is an array
# of mentions and each mention is an array with two values corresponding
# to the mention's begin and end. For example:
# @entities = ( [ [1,3], [45,45], [57,62] ], # <-- entity 0
#               [ [5,5], [25,27], [31,31] ], # <-- entity 1
# ...
# );
# entity 0 is composed by 3 mentions: from token 1 to 3, token 45 and
# from token 57 to 62 (both included)
#
# if $name is not specified, the output is a hash including each file 
# found in the document:
# $coref{$file} = \@entities
sub GetCoreference
{
	my ($file, $column, $name, $pos) = @_;
	my %coref;
	my %ind;
	
	open (F, $file) || die "Can not open $file: $!";
	if ($pos) {
		seek(F, $pos, 0);
	}
	my $fName;
	my $getout = 0;
	do {
		# look for the begin of a file
		while (my $l = <F>) {
			chomp($l);
			$l =~ s/\r$//; # m$ format jokes
			if ($l =~ /^\#\s*begin document (.*?)$/) {
				if (defined($name)) {
					if ($name eq $1) {
						$fName = $name;
						$getout = 1;
						last;
					}
				}
				else {
					$fName = $1;
					last;
				}
			}
		}
		print "====> $fName:\n" if ($VERBOSE > 1);
		
		# Extract the keys from the file until #end is found
		my $lnumber = 0;
		my @entities;
		my @half;
		my @head;
		my @sentId;
		while (my $l = <F>) {
			chomp($l);
			next if ($l eq '');
			if ($l =~ /\#\s*end document/) {
				foreach my $h (@half) {
					if (defined($h) && @$h) {
						die "Error: some mentions in the document do not close\n";
					}
				}
				last;
			}
			my @columns = split(/\t/, $l);
			my $cInfo = $columns[$column];
			push (@head, $columns[$HEAD_COLUMN]);
			push (@sentId, $columns[0]);
			if ($cInfo ne '_') {
				
				#discard double antecedent
				while ($cInfo =~ s/\((\d+\+\d)\)//) {
					print "Discarded ($1)\n" if ($VERBOSE > 1);
				}
				
				# one-token mention(s)
				while ($cInfo =~ s/\((\d+)\)//) {
					my $ie = GetIndex(\%ind, $1);
					push(@{$entities[$ie]}, [ $lnumber, $lnumber, $lnumber ]);
					print "+mention (entity $ie): ($lnumber,$lnumber)\n" if ($VERBOSE > 2);
				}
				
				# begin of mention(s)
				while ($cInfo =~ s/\((\d+)//) {
					my $ie = GetIndex(\%ind, $1);
					push(@{$half[$ie]}, $lnumber);
					print "+init mention (entity $ie): ($lnumber\n" if ($VERBOSE > 2);
				}
				
				# end of mention(s)
				while ($cInfo =~ s/(\d+)\)//) {
					my $numberie = $1;
					my $ie = GetIndex(\%ind, $numberie);
					my $start = pop(@{$half[$ie]});
					if (defined($start)) {
						my $inim = $sentId[$start];
						my $endm = $sentId[$lnumber];
						my $tHead = $start;
						# the token whose head is outside the mention is the head of the mention
						for (my $t = $start; $t <= $lnumber; $t++) {
							if ($head[$t] < $inim || $head[$t] > $endm) {
								$tHead = $t;
								last;
							}
						}
						push(@{$entities[$ie]}, [ $start, $lnumber, $tHead ]);
					}
					else {
						die "Detected the end of a mention [$numberie]($ie) without begin (?,$lnumber)";
					}
					print "+mention (entity $ie): ($start,$lnumber)\n" if ($VERBOSE > 2);
					
				}
			}
			$lnumber++;
		}
		
		# verbose
		if ($VERBOSE > 1) {
			print "File $fName:\n";
			for (my $e = 0; $e < scalar(@entities); $e++) {
				print "Entity $e:";
				foreach my $mention (@{$entities[$e]}) {
					print " ($mention->[0],$mention->[1])";
				}
				print "\n";
			}
		}
		
		$coref{$fName} = \@entities;
	} while (!$getout && !eof(F));
	
	if (defined($name)) {
		return $coref{$name};
	}
	return \%coref;
}

sub GetFileNames {
	my $file = shift;
	my %hash;
	my $last = 0;
	open (F, $file) || die "Can not open $file: $!";
	while (my $l = <F>) {
		chomp($l);
		$l =~ s/\r$//; # m$ format jokes
		if ($l =~ /^\#\s*begin document (.*?)$/) {
			my $name = $1;
			$hash{$name} = $last;
		}
		$last = tell(F);
	}
	close (F);
	return \%hash;
}

sub IdentifMentions
{
	my ($keys, $response, $totals) = @_;
	my @kChains;
	my @rChains;
	my %id;
	my %map;
	my $idCount = 0;
	my @assigned;
	
	# for each mention found in keys an ID is generated
	foreach my $entity (@$keys) {
		foreach my $mention (@$entity) {
			if (defined($id{"$mention->[0],$mention->[1]"})) {
				print "Repe: $mention->[0], $mention->[1] ", $id{"$mention->[0],$mention->[1]"}, $idCount, "\n";
			}
			$id{"$mention->[0],$mention->[1]"} = $idCount;
			$idCount++;
		}
	}
	
	# correct identification: Exact bound limits
	my $exact = 0;
	foreach my $entity (@$response) {
		foreach my $mention (@$entity) {
			if (defined($id{"$mention->[0],$mention->[1]"}) &&
				!$assigned[$id{"$mention->[0],$mention->[1]"}]) {
				$assigned[$id{"$mention->[0],$mention->[1]"}] = 1;
				$map{"$mention->[0],$mention->[1]"} = $id{"$mention->[0],$mention->[1]"};
				$exact++;
			}
		}
	}
	
	# Partial identificaiton: Inside bounds and including the head
	my $part = 0;
	foreach my $entity (@$response) {
		foreach my $mention (@$entity) {
			my $ini = $mention->[0];
			my $end = $mention->[1];
			my $head = $mention->[2];
			next if (defined($map{"$ini,$end"}));
			foreach my $ent (@$keys) {
				foreach my $m (@$ent) {
					next if ($assigned[$id{"$m->[0],$m->[1]"}]);
					if ($ini >= $m->[0] && $ini <= $m->[1] &&
						$end >= $m->[0] && $end <= $m->[1] &&
						$ini <= $m->[2] && $end >= $m->[2]) {
						$map{"$ini,$end"} = $id{"$m->[0],$m->[1]"};
						$assigned[$id{"$m->[0],$m->[1]"}] = 1;
						$part++;
						last;
					}
					last if (defined($map{"$ini,$end"}));
				}
			}
		}
	}
	
	# Each mention in response not included in keys has a new ID
	foreach my $entity (@$response) {
		foreach my $mention (@$entity) {
			my $ini = $mention->[0];
			my $end = $mention->[1];
			if (!defined($map{"$mention->[0],$mention->[1]"})) {
				$map{"$mention->[0],$mention->[1]"} = $idCount;
				$idCount++;
			}
		}
	}
	
	if ($VERBOSE) {
		print "Total key mentions: " . scalar(keys(%id)) . "\n";
		print "Total response mentions: " . scalar(keys(%map)) . "\n";
		print "Strictly correct identified mentions: $exact\n";
		print "Partially correct identified mentions: $part\n";
		print "No identified: " . (scalar(keys(%id)) - $exact - $part) . "\n";
		print "Invented: " . ($idCount - scalar(keys(%id))) . "\n";
	}
	
	if (defined($totals)) {
		$totals->{recallDen} += scalar(keys(%id));
		$totals->{recallNum} += $exact + 0.5 *$part;
		$totals->{precisionDen} += scalar(keys(%map));
		$totals->{precisionNum} += $exact + 0.5 * $part;
		$totals->{precisionExact} += $exact;
		$totals->{precisionPart} += $part;
	}
	
	# The coreference chains arrays are generated again with ID of mentions
	# instead of token coordenates
	my $e = 0;
	foreach my $entity (@$keys) {
		foreach my $mention (@$entity) {
			push(@{$kChains[$e]}, $id{"$mention->[0],$mention->[1]"});
		}
		$e++;
	}
	$e = 0;
	foreach my $entity (@$response) {
		foreach my $mention (@$entity) {
			push(@{$rChains[$e]}, $map{"$mention->[0],$mention->[1]"});
		}
		$e++;
	}
	
	return (\@kChains, \@rChains);
}

sub Eval
{
	my ($scorer, $keys, $response) = @_;
	$scorer = lc($scorer);
	my ($nr, $dr, $np, $dp);
	if ($scorer eq 'muc') {
		($nr, $dr, $np, $dp) = MUCScorer($keys, $response);
	}
	elsif ($scorer eq 'bcub') {
		($nr, $dr, $np, $dp) = BCUBED($keys, $response);
	}
	elsif ($scorer =~ /^ceafm?$/) {
		($nr, $dr, $np, $dp) = CEAF($keys, $response, 1);
	}
	elsif ($scorer eq 'ceafe') {
		($nr, $dr, $np, $dp) = CEAF($keys, $response, 0);
	}
# 	elsif ($scorer eq 'blanc') {
# 		($nr, $dr, $np, $dp) = BLANC($keys, $response);
# 	}
	else {
		die "Metric $scorer not implemented yet\n";
	}
	return ($nr, $dr, $np, $dp);
}

# Indexes an array of arrays, in order to easily know the position of an element 
sub Indexa
{
	my ($arrays) = @_;
	my %index;
	
	for (my $i = 0; $i < @$arrays; $i++) {
		foreach my $e (@{$arrays->[$i]}) {
			$index{$e} = $i;
		}
	}
	return \%index;
}

# Es consideren els "links" dintre de cada cadena de coreferents. La cadena
# A-B-C-D te 3 links: A-B, B-C i C-D. Recall: num links correctes / esperats
# Precisio: num links correctes / marcats
sub MUCScorer
{
	my ($keys, $response) = @_;
	my $kIndex = Indexa($keys);
	
	# Calculate correct links
	my $correct = 0;
	foreach my $rEntity (@$response) {
		next if (!defined($rEntity));
		# for each possible pair
		for (my $i = 0; $i < @$rEntity; $i++) {
			my $id_i = $rEntity->[$i];
			for (my $j = $i+1; $j < @$rEntity; $j++) {
				my $id_j = $rEntity->[$j];
				if (defined($kIndex->{$id_i}) && defined($kIndex->{$id_j}) &&
					$kIndex->{$id_i} == $kIndex->{$id_j}) {
					$correct++;
					last;
				}
# 				else {
# 					print "$i $id_i $kIndex->{$id_i} =? $j $id_j $kIndex->{$id_j}\n";
# 				}
			}
		}
	}
	
	# Links in key
	my $keylinks = 0;
	foreach my $kEntity (@$keys) {
		next if (!defined($kEntity));
		$keylinks += scalar(@$kEntity) - 1 if (scalar(@$kEntity));
	}
	
	# Links in response
	my $reslinks = 0;
	foreach my $rEntity (@$response) {
		next if (!defined($rEntity));
		$reslinks += scalar(@$rEntity) - 1 if (scalar(@$rEntity));
	}
	
	ShowRPF($correct, $keylinks, $correct, $reslinks) if ($VERBOSE);
	return ($correct, $keylinks, $correct, $reslinks);
}

# Per cada mencio de la resposta es calcula la precisio i per cada mencio a les
# keys es calcula el recall
sub BCUBED
{
	my ($keys, $response) = @_;
	my $kIndex = Indexa($keys);
	my $rIndex = Indexa($response);
	my $acumP = 0;
	my $acumR = 0;
	foreach my $rChain (@$response) {
		foreach my $m (@$rChain) {
			my $kChain = (defined($kIndex->{$m})) ? $keys->[$kIndex->{$m}] : [];
			my $ci = 0;
			my $ri = scalar(@$rChain);
			my $ki = scalar(@$kChain);
			
			# common mentions in rChain and kChain => Ci
			foreach my $mr (@$rChain) {
				foreach my $mk (@$kChain) {
					if ($mr == $mk) {
						$ci++;
						last;
					}
				}
			}
			
			$acumP += $ci / $ri if ($ri);
			$acumR += $ci / $ki if ($ki);
		}
	}
	
	# Mentions in key
	my $keymentions = 0;
	foreach my $kEntity (@$keys) {
		$keymentions += scalar(@$kEntity);
	}
	
	# Mentions in response
	my $resmentions = 0;
	foreach my $rEntity (@$response) {
		$resmentions += scalar(@$rEntity);
	}
	
	ShowRPF($acumR, $keymentions, $acumP, $resmentions) if ($VERBOSE);
	return($acumR, $keymentions, $acumP, $resmentions);
}

sub SIMEntityBased
{
	my ($a, $b) = @_;
	my $intersection = 0;
	
	# Common elements in A and B
	foreach my $ma (@$a) {
		next if (!defined($ma));
		foreach my $mb (@$b) {
			next if (!defined($mb));
			if ($ma == $mb) {
				$intersection++;
				last;
			}
		}
	}
	
	my $r = 0;
	my $d = scalar(@$a) + scalar(@$b);
	if ($d != 0) {
		$r = 2 * $intersection / $d;
	}
	
	return $r;
}

sub SIMMentionBased
{
	my ($a, $b) = @_;
	my $intersection = 0;
	
	# Common elements in A and B
	foreach my $ma (@$a) {
		next if (!defined($ma));
		foreach my $mb (@$b) {
			next if (!defined($mb));
			if ($ma == $mb) {
				$intersection++;
				last;
			}
		}
	}
	
	return $intersection;
}

# type = 0: Entity-based
# type = 1: Mention-based
sub CEAF
{
	my ($keys, $response, $type) = @_;
	
	my @sim;
	for (my $i = 0; $i < scalar(@$keys); $i++) {
		for (my $j = 0; $j < scalar(@$response); $j++) {
			if (defined($keys->[$i]) && defined($response->[$j])) {
				if ($type == 0) { # entity-based
					$sim[$i][$j] = 1 - SIMEntityBased($keys->[$i], $response->[$j]);
					# 1 - X => the library searches minima not maxima
				}
				elsif ($type == 1) { # mention-based
					$sim[$i][$j] = 1 - SIMMentionBased($keys->[$i], $response->[$j]);
				}
			}
			else {
				$sim[$i][$j] = 1;
			}
		}
		
		# fill the matrix when response chains are less than key ones
		for (my $j = scalar(@$response); $j < scalar(@$keys); $j++) {
			$sim[$i][$j] = 1;
		}
		#$denrec += SIMEntityBased($kChain->[$i], $kChain->[$i]);
	}
	
	my @out;
	
	# Munkres algorithm
	assign(\@sim, \@out);
	
	my $numerador = 0;
	my $denpre = 0;
	my $denrec = 0;
	
	# entity-based
	if ($type == 0) {
		foreach my $c (@$response) {
			$denpre++ if (defined($c) && scalar(@$c) > 0);
		}
		foreach my $c (@$keys) {
			$denrec++ if (defined($c) && scalar(@$c) > 0);
		}
	}
	# mention-based
	elsif ($type == 1) {
		foreach my $c (@$response) {
			$denpre += scalar(@$c) if (defined($c));
		}
		foreach my $c (@$keys) {
			$denrec += scalar(@$c) if (defined($c));
		}
	}
	
	for (my $i = 0; $i < scalar(@$keys); $i++) {
		$numerador += 1 - $sim[$i][$out[$i]];
	}
	
	ShowRPF($numerador, $denrec, $numerador, $denpre) if ($VERBOSE);
	
	return ($numerador, $denrec, $numerador, $denpre);
}

sub BLANC
{
	my ($keys, $response) = @_;
	my ($ga, $gr, $ba, $br) = (0, 0, 0, 0);
	
	# Each possible pair of mentions
	my $kIndex = Indexa($keys);
	my $rIndex = Indexa($response);
	
	my @ri = keys(%{$rIndex});
	for (my $i = 0; $i < @ri - 1; $i++) {
		my $m_i = $ri[$i];
		for (my $j = $i+1; $j < @ri; $j++) {
			my $m_j = $ri[$j];
			# atraction
			if ($rIndex->{$m_i} == $rIndex->{$m_j}) {
				if ($kIndex->{$m_i} == $kIndex->{$m_j}) {
					$ga++;
				}
				else {
					$ba++;
				}
			}
			# repulsion
			else {
				if ($kIndex->{$m_i} != $kIndex->{$m_j}) {
					$gr++;
				}
				else {
					$br++;
				}
			}
		}
	}
	
	if ($VERBOSE) {
		print "Coreference links: ";
		ShowRPF($ga, ($ga + $br), $ga, ($ga + $ba));
		print "Non-coreference links: ";
		ShowRPF($gr, ($gr + $ba), $gr, ($gr + $br));
		print "Mean: ";
		
		my $Pa = ($ga + $ba) ? $ga / ($ga + $ba) : 0;
		my $Pr = ($gr + $br) ? $gr / ($gr + $br) : 0;
		my $Ra = ($ga + $br) ? $ga / ($ga + $br) : -1;
		my $Rr = ($gr + $ba) ? $gr / ($gr + $ba) : -1;
		
		my $R = ($Ra + $Rr) / 2;
		my $P = ($Pa + $Pr) / 2;
		my $Fa = ($Pa + $Ra) ? 2 * $Pa * $Ra / ($Pa + $Ra) : 0;
		my $Fr = ($Pr + $Rr) ? 2 * $Pr * $Rr / ($Pr + $Rr) : 0;
		my $f1 = ($Fa + $Fr) / 2;
		
		if ($Ra == -1 && $Rr == -1) {
			$R = 0;
			$P = 0;
			$f1 = 0;
		}
		elsif ($Ra == -1) {
			$R = $Rr;
			$P = $Pr;
			$f1 = $Fr;
		}
		elsif ($Rr == -1) {
			$R = $Ra;
			$P = $Pa;
			$f1 = $Fa;
		}
		ShowRPF($R, 1, $P, 1, $f1);
	}
	
	return ($ga, ($ga + $br), $ga, ($ga + $ba), $gr, ($gr + $ba), $gr, ($gr + $br));
}


sub ShowRPF
{
	my ($numrec, $denrec, $numpre, $denpre, $f1) = @_;
	
	my $precisio = $denpre ? $numpre / $denpre : 0;
	my $recall = $denrec ? $numrec / $denrec : 0;
	if (!defined($f1)) {
		$f1 = 0;
		if ($recall + $precisio) {
			$f1 = 2 * $precisio * $recall / ($precisio + $recall);
		}
	}
	
	print "Recall: ($numrec / $denrec) " . int($recall*10000)/100 . '%';
	print "\tPrecision: ($numpre / $denpre) " . int($precisio*10000)/100 . '%';
	print "\tF1: " . int($f1*10000)/100 . "\%\n";
}
  
1;
