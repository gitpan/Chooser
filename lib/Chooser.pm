package Chooser;

use warnings;
use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our @ISA         = qw(Exporter);
our @EXPORT      = qw(choose);
our @EXPORT_OK   = qw(choose);
our %EXPORT_TAGS = (DEFAULT => [qw(choose)]);

sub argstohash{
	my $argsString=$_[0];

	my @argsStringSplit=split(/\|/, $argsString);

	my %args=();

	#puts a hash of arguements together
	my $argInt=0; #starting at 2 as it is the next in the line
	while(defined($argsStringSplit[$argInt])){
		my @argsplit=split(/=/, $argsStringSplit[$argInt]);
		$args{$argsplit[0]}="";
		
		my $argsAssembleInt=1;
		
		while(defined $argsplit[$argsAssembleInt]){
			#Adds = onto the arg if it is more than one.
			#This is placed here add = back into it and then only after the first one.
			if($argsAssembleInt > 1){
				$args{$argsplit[0]}=$args{$argsplit[0]}."=";
			};
			$args{$argsplit[0]}=$argsplit[$argsAssembleInt];
			
			$argsAssembleInt++;
		};

			$argInt++;
		};
	
	return %args;
};

#checks if a check is good or not
sub checklegit{
	my $check=$_[0];
	
	if (!defined($check)){
		return undef;
	};

	my @checks=("eval", "cidr", "hostregex", "defaultgateway", "netidentflag", "pingmac");
	
	my $checksInt=0;
	while($checks[$checksInt]){

		if ($checks[$checksInt] eq $check){
			return 1
		};
		
		$checksInt++;
	};
	return undef;
};

sub runcheck{
	my $check=$_[0];
	my %args=%{$_[1]};

	my $returned=undef;
	my $success=undef;

	if ($check eq "pingmac"){
		($success, $returned)=pingmac(\%args);
	};

	if ($check eq "defgateway"){
		($success, $returned)=defgateway(\%args);
	};

	if ($check eq "cidr"){
		($success, $returned)=cidr(\%args);
	};
	
	if ($check eq "eval"){
		if (defined($args{eval})){
			($success, $returned)=eval($args{eval});
		};
	};

	if ($check eq "hostregex"){
		my $hostname=`hostname`;
		chomp($hostname);
		
		if ($hostname =~ /$args{regex}/){
			$returned=1;
		};
		$success=1;
	};
	
	if($check eq "netidentflag"){
		my $flagdir='/var/db/netident';
		
		if (defined($ENV{NETIDENTFLAGDIR})){
			$flagdir=$ENV{NETIDENTFLAGDIR};
		};
		
		if(defined{$args{flag}}){
			if (-f $flagdir."/".$args{flag}){
				$success=1;
				$returned=1;
			}else{
				$returned=0;
			};
		}else{
			$success=0;
		};
		
	};
	
	return ($success, $returned);
};

#do a default gateway test
sub defgateway{
	my %args= %{$_[0]};
  
  	#gets it and breaks it down to a string
	my @raw=`route get default`;
	my @gateway=grep(/gateway:/, @raw);
	$gateway[0] =~ s/ //g;
	$gateway[0] =~ s/gateway://g;
	chomp($gateway[0]);

	if($args{ip} eq $gateway[0]){
		return 1;
	};

	return "0";
};

#pings a ip address and checks the mac
sub pingmac{
#  my $subargs = { %{$_[0]} };
  my %args= %{$_[0]};

  system("ping -c 1 ".$args{ip}." > /dev/null");
  if ( $? == 0 ){
    my $arpline=`arp $args{ip}`;
    my @a=split(/ at /, $arpline);
    my @b=split(/ on /, $a[1]);
    if ($b[0] eq $args{mac}){
      return "1";
    };
  };

  return "0";
};

#do a default gateway test
sub cidr{
	my %args= %{$_[0]};

	my $cidr = Net::CIDR::Lite->new;
	
	$cidr->add($args{cidr});
	
	my $socket = IO::Socket::INET->new(Proto=>'udp');
	
	my @iflist=$socket->if_list();
	
	#if a interface is not specified, make sure it exists
	if(defined($args{if})){
		my $iflistInt=0;#used for intering through @iflist
		while(defined($iflist[$iflistInt])){
			#checks if this is the interface in question
			if($iflist[$iflistInt] eq $args{if}){
				#gets the address
				my $address=$socket->if_addr($args{if});
				#if the interface does not have a address, don't check it
				if(defined($address)){
					#checks this address is with in this cidr
					if ($cidr->find($address)){
						return 1;
					};
				};
			};
			
			$iflistInt++;
		};
		
		#if a specific IP is defined and it reaches this point, it means it was now found
		return "0";
	};

	#if a interface is not specified, make sure it exists
	my $iflistInt=0;#used for intering through @iflist
	while(defined($iflist[$iflistInt])){
		#gets the address
		my $address=$socket->if_addr($iflist[$iflistInt]);
		#if the interface does not have a address, don't check it
		if(defined($address)){
			#checks this address is with in this cidr
			if ($cidr->find($address)){
				return 1;
			};
		};
		$iflistInt++;
	};

	return "0";
};

#process the value
sub valueProcess{
	my $value=$_[0];
	my $returned=$_[1];
	
	if (!$value =~ /^\%/){
		return $value;
	};

	#works just like %env{whatever} in perl
	if ($value =~ /^\%env\{/){
		$value =~ s/\%env\{//g;
		$value =~ s/\}$//g;

		return $ENV{$value};
	};

		#works just like %env{whatever} in perl
	if ($value =~ /^\%eval\{/){
		$value =~ s/\%eval\{//g;
		$value =~ s/\}$//g;

		return eval($value);
	};
	
	#sets the value to the hostname
	if ($value =~ /^\%hostname$/){
		$value = `hostname`;
		chomp($value);
		return $value;
	};

	if ($value =~ /^\%returned$/){
		$value = $returned;
	};
	
	return $value;
};

=head1 NAME

Chooser - A system for choosing a value for something.

=head1 VERSION

Version 1.1.3

=cut

our $VERSION = '1.1.3';


=head1 SYNOPSIS

Takes a string composed of various tests, arguements, and etc and 
returns a value based on it. See FORMATTING for more information on
the string.

    use Chooser;

    my $foo = choose($string);
    ...

=head1 EXPORT

chooose

=head1 FUNCTIONS

=head2 choose

This function is used for running a chooser string. See FORMATING for information
on the string passed to it.

If any of the lines in the string contain errors, choose returns a error.

There are two returns. The first return is a bolean for if it succedded or not. The
second is the choosen value.

=cut

#parse and run a string
sub choose{
	my $string=$_[0];

	if (!defined($string)){
		return (0, undef);
	};

	my @rawdata=split(/\n/, $string);

	my $value;
	my %values=();
	
	my $int=0;
	while(defined($rawdata[$int])){
		my $line=$rawdata[$int];
		chomp($line);

		my ($check, $restofline)=split(/\|/, $line, 2);
		(my $expect, $restofline)=split(/\|/, $restofline, 2);
		(my $value, $restofline)=split(/\|/, $restofline, 2);
		(my $wieght, $restofline)=split(/\|/, $restofline, 2);
		(my $argsString, $restofline)=split(/\|/, $restofline, 2);
		my %args=argstohash($argsString);

		if (!defined($wieght)){
			$wieght=0
		};

		#if the check is legit, run it
		if(checklegit($check)){
			my ($success, $returned)=runcheck($check, \%args);
			#makes sure the check was sucessful
			if ($success){
				if ($returned eq $expect){
						$value=valueProcess($value, $returned);
						$values{$value}=$wieght;
				};
			};
			
		}else{
			return 0;
		};

		$int++;
	};

	#finds the heaviest value
	my @keys=keys(%values);
	my $keysInt=0;
	if(defined($keys[$keysInt])){
		$value=$keys[$keysInt];
		my $lastwieght=$values{$keys[$keysInt]};
		while(defined($keys[$keysInt])){
			#if the value is heavier or equal to the last one, use it
			if ($values{$keys[$keysInt]} >= $lastwieght){
				$value=$keys[$keysInt];
			};
			$keysInt++;
		};
	};
	print $value;
	return (1, $value);
};

=head1 FORMATTING

	<check>|<expect>|<value>|<wieght>|<arg0>=<argValue0>|<arg1>=<argValue1>...

'|' is used a delimiter and there is no whitespace.

For information on the support checks, see the CHECK sections.

The expect section is the expected turn value for a check. Unless stated other wise
it is going to be '0' for false and '1' for true.

The value is the return value for if it is true. The eventual returned one is choosen
by the wieght. The highest number takes presdence. If equal, the last value is used.

The wieght is the way for the returned value.

The args are every thing after the wieght. Any thing before the first '=' is considered
part of the variable name. The variable name is case sensitive. Everything after the first
'=' is considered part of the value of the variable.

=head1 CHECKS

=head2 pingmac

This test pings a IP to make sure it is in the ARP table and then checks to see if the MAC maches.

The arguement for the IP is "ip".

The arguement for the MAC is "mac".

=head2 defgateway

This checks the routing table for the default route and compares it to passed variable.

The arguement "ip" is used for the default gateway.

=head2 cidr

This checks if a specific interface or any of them have a address that matches a given CIDR.

The arguement "cidr" is CIDR to be matched.

The arguement "if" is optional arguement for the interface.

=head2 hostregex

This runs a regex over the hostname and turns true if it matches.

The arguement "regex" is the regex to use.

=head2 eval

This runs some perl code. This requires two things being returned. The first
thing that needs returned is success of check. This is if the if there as a error
or not with the check. It needs to return true or the choose function returns with
an error condition. The second returned value is the value that is checked against
expect value.

The arguement "eval" is the arguement that contains the code used for this.

=head2 netidentflag

This tests to see if a flag created by netident is present. The directory used is the
default netident flag directory, unless the enviromental variable 'NETIDENTFLAGDIR' is
set.

The arguement "flag" is used to specify the flag to look for.

=head1 AUTHOR

Zane C. Bowers, C<< <vvelox at vvelox.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-chooser at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Chooser>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Chooser


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Chooser>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Chooser>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Chooser>

=item * Search CPAN

L<http://search.cpan.org/dist/Chooser>

=back



=head1 COPYRIGHT & LICENSE

Copyright 2008 Zane C. Bowers, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Chooser
