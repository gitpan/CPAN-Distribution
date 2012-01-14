package CPAN::Distribution;
BEGIN {
  $CPAN::Distribution::AUTHORITY = 'cpan:GETTY';
}
{
  $CPAN::Distribution::VERSION = '0.001';
}
# ABSTRACT: API to access a CPAN Distribution file or directory

use Moo;
use Archive::Any;
use CPAN::Meta;
use File::Temp qw/ tempfile tempdir /;
use File::Find::Object;
use Module::Extract::Namespaces;
use DateTime::Format::Epoch::Unix;

has filename => (
	is => 'ro',
	predicate => 'has_filename',
);

has archive => (
	is => 'ro',
	lazy => 1,
	builder => '_build_archive',
);

sub _build_archive {
	my ( $self ) = @_;
	die __PACKAGE__.": need a filename" unless $self->has_filename;
	return Archive::Any->new($self->filename);
}

has distmeta => (
	is => 'ro',
	lazy => 1,
	builder => '_build_distmeta',
	handles => [qw(
		abstract
		description
		dynamic_config
		generated_by
		name
		release_status
		version
		authors
		keywords
		licenses
		meta_spec
		resources
		provides
		no_index
		prereqs
		optional_features
	)]
);

sub _build_distmeta {
	my ( $self ) = @_;
	if ($self->files->{'META.yml'}) {
		CPAN::Meta->load_file($self->files->{'META.yml'});
	} elsif ($self->files->{'META.json'}) {
		CPAN::Meta->load_file($self->files->{'META.json'});
	}
}

has dir => (
	is => 'ro',
	predicate => 'has_dir',
);

has files => (
	is => 'ro',
	lazy => 1,
	builder => '_build_files',
);

sub _build_files {
	my ( $self ) = @_;
	my $dir = $self->has_dir ? $self->dir : tempdir;
	if ($self->has_filename) {
		if (!-f "$dir/Makefile.PL") {
			my $ext_dir = tempdir;
			$self->archive->extract($ext_dir);
			for ($self->get_directory_tree($ext_dir)) {
				my @components = @{$_->full_components};
				shift @components;
				if ($_->is_dir) {
					mkdir $dir.'/'.join('/',@components);
				} else {
					rename $_->path, $dir.'/'.join('/',@components);
				}
			}
		}
	}
	my %files;
	for ($self->get_directory_tree($dir)) {
		$files{join('/',@{$_->full_components})} = $_->path if $_->is_file;
	}
	return \%files;
}

has packages => (
	is => 'ro',
	lazy => 1,
	builder => '_build_packages',
);

sub _build_packages {
	my ( $self ) = @_;
	my %packages;
	for (keys %{$self->files}) {
		my $key = $_;
		my @components = split('/',$key);
		if ($key =~ /\.pm$/) {
			my @namespaces = Module::Extract::Namespaces->from_file($self->files->{$key});
			for (@namespaces) {
				$packages{$_} = [] unless defined $packages{$_};
				push @{$packages{$_}}, $key;
			}
		} elsif ($key =~ /^lib\// && $key =~ /\.pod$/) {
			my $packagename = $key;
			$packagename =~ s/^lib\///g;
			$packagename =~ s/\.pod$//g;
			$packagename =~ s/\//::/g;
			$packages{$packagename} = [] unless defined $packages{$packagename};
			push @{$packages{$packagename}}, $key;
		}
	}
	return \%packages;
}

has scripts => (
	is => 'ro',
	lazy => 1,
	builder => '_build_scripts',
);

sub _build_scripts {
	my ( $self ) = @_;
	my %scripts;
	for (keys %{$self->files}) {
		next unless $_ =~ /^bin\// || $_ =~ /^script\//;
		my $key = $_;
		my @components = split('/',$key);
		shift @components;
		$scripts{join('/',@components)} = $key;
	}
	return \%scripts;
}

sub get_directory_tree {
	my ( $self, @dirs ) = @_;
	my $tree = File::Find::Object->new({}, @dirs);
	my @files;
	while (my $r = $tree->next_obj()) {
		push @files, $r;
	}
	return @files;
}

sub file {
	my ( $self, $file ) = @_;
	return $self->files->{$file};
}

sub modified {
    my ( $self ) = @_;
    my $mtime = stat($self->has_filename ? $self->filename : $self->dir )->mtime;
    return DateTime::Format::Epoch::Unix->parse_datetime($mtime);
}

sub BUILDARGS {
	my ( $self, @args ) = @_;
	die __PACKAGE__.": please give filename or Archive::Any compatible object on new" if !@args;
	if ( @args == 1 ) {
		my $arg = $args[0];
		my $ref = ref $arg;
		return @args if $ref eq 'HASHREF';
		if ($ref) {
			return { archive => $arg };
		} else {
			# should support URL also
			if (-f $arg) {
				return { filename => $arg };
			} elsif (-d $arg) {
				return { dir => $arg };
			}
		}
	}
	return @args;
}

1;


__END__
=pod

=head1 NAME

CPAN::Distribution - API to access a CPAN Distribution file or directory

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  use CPAN::Distribution;

  my $cpandist = CPAN::Distribution->new("My-Sample-Distribution-0.003.tar.gz");

  my %files = %{$cpandist->files};

  my $filename_of_distini = $cpandist->file('dist.ini');

  my $cpan_meta = $cpandist->distmeta; # gives back CPAN::Meta

  my $version = $cpandist->version; # handled by CPAN::Meta object
  my $name = $cpandist->name;       # also

  my @authors = $cpandist->authors;

  my %packages = %{$cpandist->packages};
  my %scripts = %{$cpandist->scripts};

=head1 DESCRIPTION

This distribution is used to get all information from a CPAN distribution or an extracted CPAN distribution. It tries to combine the power of other modules. Longtime it should be possible to define alternative behaviour (to be more like search.cpan.org or be like metacpan.org or whatever other system that parses CPAN Distributions).

=encoding utf8

=head1 SUPPORT

IRC

  Join #duckduckgo on irc.freenode.net. Highlight Getty for fast reaction :).

Repository

  http://github.com/Getty/p5-cpan-distribution
  Pull request and additional contributors are welcome

Issue Tracker

  http://github.com/Getty/p5-cpan-distribution/issues

=head1 AUTHOR

Torsten Raudssus <torsten@raudss.us> L<http://raudss.us/>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by DuckDuckGo, Inc. L<http://duckduckgo.com/>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

