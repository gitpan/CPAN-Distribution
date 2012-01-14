#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

use CPAN::Distribution;

BEGIN {

	my $cpandist = CPAN::Distribution->new("$Bin/data/My-Sample-Distribution-0.003.tar.gz");

	isa_ok($cpandist,'CPAN::Distribution');
	
	my $archive = $cpandist->archive;

	isa_ok($archive,'Archive::Any');

	my @keys = sort keys %{$cpandist->files};
	
	is_deeply(\@keys,[qw(
		Changes
		LICENSE
		MANIFEST
		META.json
		META.yml
		Makefile.PL
		README
		bin/my_sample_distribution
		dist.ini
		lib/My/Sample/Distribution.pm
		lib/My/Sample/Documentation.pod
		t/release-pod-syntax.t
	)],'Checking files');

	like($cpandist->file('dist.ini'),qr/\/dist.ini$/,'Checking if file function gives back valid filename');
	ok(-f $cpandist->file('dist.ini'),'Checking if file exist');
	is((stat($cpandist->file('dist.ini')))[7],214,'Checking filesize');
	
	isa_ok($cpandist->distmeta,'CPAN::Meta');
	
	is($cpandist->version,'0.003','Checking version from meta');
	is($cpandist->name,'My-Sample-Distribution','Checking name from meta');
	is($cpandist->generated_by,'Dist::Zilla version 4.300003, CPAN::Meta::Converter version 2.113640','Checking generated_by from meta');
	
	is_deeply([$cpandist->authors],['Torsten Raudssus <torsten@raudssus.de>','Another Author <someone@somewhere>'],'Checking authors from meta');

	is_deeply($cpandist->meta_spec,{
		version => 2,
		url => 'http://search.cpan.org/perldoc?CPAN::Meta::Spec',
	},'Checking meta specification from meta');
	
	is_deeply($cpandist->packages, {
		'My::Sample::Distribution' => ['lib/My/Sample/Distribution.pm'],
		'My::Sample::Documentation' => ['lib/My/Sample/Documentation.pod'],
	},'Checking package definitions');

	is_deeply($cpandist->scripts, {
		'my_sample_distribution' => 'bin/my_sample_distribution',
	},'Checking scripts definitions');

}

done_testing;
