package Dist::Zilla::Plugin::Repository;

# ABSTRACT: Automatically sets repository URL from svn/svk/Git checkout for Dist::Zilla

use Moose;
with 'Dist::Zilla::Role::MetaProvider';

=head1 SYNOPSIS
 
    # dist.ini
    [Repository]

=head1 DESCRIPTION

The code is mostly a copy-paste of L<Module::Install::Repository>

=head2 ATTRIBUTES

=over 4

=item * git_remote

This is the name of the remote to use for the public repository (if
you use Git). By default, unsurprisingly, to F<origin>.

=item * github_http

If the remote is a GitHub repository, uses the http url
(http://github.com/fayland/dist-zilla-plugin-repository) rather than the actual
clonable url (git://github.com/fayland/dist-zilla-plugin-repository.git).
Defaults to true.

=back

=cut

has git_remote => (
  is   => 'ro',
  isa  => 'Str',
  default  => 'origin',
);

has github_http => (
  is   => 'ro',
  isa  => 'Bool',
  default  => 1,
);

sub metadata {
    my ($self, $arg) = @_;

    my $repo = $self->_find_repo(\&_execute);
    return { resources => { repository => { url => $repo } } };
}

sub _execute {
    my ($command) = @_;
    `$command`;
}

# Copy-Paste of Module-Install-Repository, thank MIYAGAWA
sub _find_repo {
    my ($self, $execute) = @_;
    
    if (-e ".git") {
        if ($execute->('git remote show -n '
                       . $self->git_remote) =~ /URL: (.*)$/m) {
            # XXX Make it public clone URL, but this only works with github
            my $git_url = $1;
            $git_url =~ s![\w\-]+\@([^:]+):!git://$1/!;
            
            # Changed
            # I prefer http://github.com/fayland/dist-zilla-plugin-repository
            #   than git://github.com/fayland/dist-zilla-plugin-repository.git 
            if ( $self->github_http
              && $git_url =~ /^git:\/\/(github\.com.*?)\.git$/ ) {
                $git_url = "http://$1";
            }
            
            return if $git_url eq 'origin'; # RT 55136
            return $git_url;
        } elsif ($execute->('git svn info') =~ /URL: (.*)$/m) {
            return $1;
        }
    } elsif (-e ".svn") {
        if ($execute->('svn info') =~ /URL: (.*)$/m) {
            my $svn_url = $1;
            if( $svn_url =~ /^https(\:\/\/.*?\.googlecode\.com\/svn\/.*)$/ ) {
                $svn_url = 'http'.$1;
            }
            return $svn_url;
        }
    } elsif (-e "_darcs") {
        # defaultrepo is better, but that is more likely to be ssh, not http
        if (my $query_repo = $execute->('darcs query repo')) {
            if ($query_repo =~ m!Default Remote: (http://.+)!) {
                return $1;
            }
        }

        open my $handle, '<', '_darcs/prefs/repos' or return;
        while (<$handle>) {
            chomp;
            return $_ if m!^http://!;
        }
    } elsif (-e ".hg") {
        if ($execute->('hg paths') =~ /default = (.*)$/m) {
            my $mercurial_url = $1;
            $mercurial_url =~ s!^ssh://hg\@(bitbucket\.org/)!https://$1!;
            return $mercurial_url;
        }
    } elsif (-e "$ENV{HOME}/.svk") {
        # Is there an explicit way to check if it's an svk checkout?
        my $svk_info = $execute->('svk info') or return;
        SVK_INFO: {
            if ($svk_info =~ /Mirrored From: (.*), Rev\./) {
                return $1;
            }

            if ($svk_info =~ m!Merged From: (/mirror/.*), Rev\.!) {
                $svk_info = $execute->("svk info /$1") or return;
                redo SVK_INFO;
            }
        }

        return;
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
