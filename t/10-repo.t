#! /usr/bin/perl
#---------------------------------------------------------------------

use strict;
use warnings;
use Test::More tests => 14;

use Dist::Zilla::Tester;

#---------------------------------------------------------------------
# Fake execution of VCS commands:

use Dist::Zilla::Plugin::Repository; # make sure it's already loaded

my %result;

{
  package Dist::Zilla::Plugin::Repository;
  no warnings 'redefine';
  sub _execute {
    my $cmd = shift;
    $result{$cmd} || die "Unexpected command <$cmd>";
  }
}

$result{'git remote show -n origin'} = <<'END GIT';
* remote origin
  Fetch URL: git@github.com:fayland/dist-zilla-plugin-repository.git
  Push  URL: git@github.com:fayland/dist-zilla-plugin-repository.git
  HEAD branch: (not queried)
  Remote branch: (status not queried)
    master
  Local branch configured for 'git pull':
    master merges with remote master
  Local ref configured for 'git push' (status not queried):
    (matching) pushes to (matching)
END GIT

$result{'git remote show -n dzil'} = <<'END GIT DZIL';
* remote dzil
  Fetch URL: git://github.com/rjbs/dist-zilla.git
  Push  URL: git://github.com/rjbs/dist-zilla.git
  HEAD branch: (not queried)
  Remote branches: (status not queried)
    config-mvp-reader
    cpan-meta-prereqs
    master
    new-classic
    prereq-overhaul
  Local ref configured for 'git push' (status not queried):
    (matching) pushes to (matching)
END GIT DZIL

$result{'svn info'} = <<'END SVN';
Path: .
URL: http://example.com/svn/trunk/my-project
Repository Root: http://example.com/svn
Repository UUID: 12345678-9012-3456-7890-123456789012
Revision: 1234
Node Kind: directory
Schedule: normal
Last Changed Author: example
Last Changed Rev: 1234
Last Changed Date: 2008-09-27 15:42:32 -0500 (Sat, 27 Sep 2008)
END SVN

$result{'darcs query repo'} = <<'END DARCS';
          Type: darcs
        Format: darcs-1.0
          Root: /home/user/foobar
      Pristine: PlainPristine "_darcs/pristine"
         Cache: thisrepo:/home/user/foobar
Default Remote: http://example.com/darcs
   Num Patches: 2
END DARCS

$result{'hg paths'} = <<'END HG';
default = https://foobar.googlecode.com/hg/
END HG

#---------------------------------------------------------------------
sub make_ini
{
  my $ini = <<'END START';
name     = DZT-Sample
author   = E. Xavier Ample <example@example.org>
license  = Perl_5
copyright_holder = E. Xavier Ample
version  = 0.01

[GatherDir]
[Repository]
END START

  $ini . join('', map { "$_\n" } @_);
} # end make_ini

#---------------------------------------------------------------------
sub build_tzil
{
  my $repo = shift || [];

  my @extra_files;
  while (@_) {
    push @extra_files, "source/" . shift;
    push @extra_files, @_ ? shift : '';
  }

  my $tzil = Builder->from_config(
    { dist_root => 't/corpus/DZT' },
    {
      add_files => {
        'source/dist.ini' => make_ini(@$repo),
        @extra_files,
      },
    },
  );

  $tzil->build;

  return $tzil;
} # end build_tzil

#=====================================================================
{
  my $tzil = build_tzil();

  is($tzil->distmeta->{resources}{repository}, undef, "No repository");
}

#---------------------------------------------------------------------
{
  my $url = 'http://example.com';

  my $tzil = build_tzil([ "repository = $url" ]);

  is_deeply($tzil->distmeta->{resources}{repository},
            { url => $url }, "Just a URL");
}

#---------------------------------------------------------------------
{
  my $url = 'http://example.com/svn/repo';

  my $tzil = build_tzil([ "repository = $url", 'type = svn' ]);

  is_deeply($tzil->distmeta->{resources}{repository},
            { url => $url, type => 'svn' }, "SVN with type");
}

#---------------------------------------------------------------------
{
  my $url = 'http://example.com/svn/repo';
  my $web = 'http://example.com';

  my $tzil = build_tzil([ "repository = $url", "web = $web", 'type = svn' ]);

  is_deeply(
      $tzil->distmeta->{resources}{repository},
      { web => $web, url => $url, type => 'svn' }, "SVN with type and web"
  );
}

#---------------------------------------------------------------------
{
  my $tzil = build_tzil([], '.git');

  is_deeply(
      $tzil->distmeta->{resources}{repository},
      { type => 'git',
        url => 'http://github.com/fayland/dist-zilla-plugin-repository',
        web => 'http://github.com/fayland/dist-zilla-plugin-repository' },
      "Auto github"
  );
}

#---------------------------------------------------------------------
{
  my $tzil = build_tzil(['github_http = 0'], '.git');

  is_deeply(
      $tzil->distmeta->{resources}{repository},
      { type => 'git',
        url => 'git://github.com/fayland/dist-zilla-plugin-repository.git',
        web => 'http://github.com/fayland/dist-zilla-plugin-repository' },
      "Auto github no http"
  );
}

#---------------------------------------------------------------------
{
  my $tzil = build_tzil(['git_remote = dzil'], '.git');

  is_deeply(
      $tzil->distmeta->{resources}{repository},
      { type => 'git',
        url => 'http://github.com/rjbs/dist-zilla',
        web => 'http://github.com/rjbs/dist-zilla' },
      "Auto github remote dzil"
  );
}

#---------------------------------------------------------------------
{
  my $tzil = build_tzil(['git_remote = dzil', 'github_http = 0'], '.git');

  is_deeply(
      $tzil->distmeta->{resources}{repository},
      { type => 'git',
        url => 'git://github.com/rjbs/dist-zilla.git',
        web => 'http://github.com/rjbs/dist-zilla' },
      "Auto github remote dzil no http"
  );
}

#---------------------------------------------------------------------
{
  my $tzil = build_tzil([], '.svn');

  is_deeply(
      $tzil->distmeta->{resources}{repository},
      { type => 'svn',
        url => 'http://example.com/svn/trunk/my-project' },
      "Auto svn"
  );
}

#---------------------------------------------------------------------
{
  my $web = 'http://example.com';

  my $tzil = build_tzil(["web = $web"], '.svn');

  is_deeply(
      $tzil->distmeta->{resources}{repository},
      { type => 'svn', web => $web,
        url => 'http://example.com/svn/trunk/my-project' },
      "Auto svn with web"
  );
}

#---------------------------------------------------------------------
{
  my $tzil = build_tzil([], '_darcs');

  is_deeply(
      $tzil->distmeta->{resources}{repository},
      { type => 'darcs',
        url => 'http://example.com/darcs' },
      "Auto darcs from default remote"
  );
}

#---------------------------------------------------------------------
{
  my $url = 'http://example.com/darcs/fromprefs';

  # Munge the Default Remote so it's not http:
  local $result{'darcs query repo'} = $result{'darcs query repo'};
  $result{'darcs query repo'} =~ s!Remote: http!Remote: ssh!;

  my $tzil = build_tzil([], '_darcs/prefs/repos' => "ssh:foo\n$url\n");

  is_deeply(
      $tzil->distmeta->{resources}{repository},
      { type => 'darcs', url => $url },
      "Auto darcs from prefs/repos"
  );
}

#---------------------------------------------------------------------
{
  my $tzil = build_tzil([], '.hg');

  is_deeply(
      $tzil->distmeta->{resources}{repository},
      { type => 'hg', url => 'https://foobar.googlecode.com/hg/' },
      "Auto hg"
  );
}

#---------------------------------------------------------------------
{
  my $web = 'http://code.google.com/p/foobar/';
  my $tzil = build_tzil(["web = $web"], '.hg');

  is_deeply(
      $tzil->distmeta->{resources}{repository},
      { type => 'hg', web => $web,
        url => 'https://foobar.googlecode.com/hg/' },
      "Auto hg with web"
  );
}

#---------------------------------------------------------------------
done_testing;
