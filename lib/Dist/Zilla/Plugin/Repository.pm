package Dist::Zilla::Plugin::Repository;

# ABSTRACT: Automatically sets repository URL from svn/svk/Git checkout for Dist::Zilla

use Moose;
with 'Dist::Zilla::Role::MetaProvider';

=head1 SYNOPSIS
 
    # dist.ini
    [Repository]

=head1 DESCRIPTION

The code is mostly a copy-paste of L<Module::Install::Repository>
 
=cut

sub metadata {
    my ($self, $arg) = @_;

    my $repo = $self->_find_repo();
    return { resources => { repository => $repo } };
}

# Copy-Paste of Module-Install-Repository, thank MIYAGAWA
sub _find_repo {
  my ($self) = @_;
    if (-e ".git") {
        # TODO support remote besides 'origin'?
        if (`git remote show origin` =~ /URL: (.*)$/m) {
            # XXX Make it public clone URL, but this only works with github
            my $git_url = $1;
            $git_url =~ s![\w\-]+\@([^:]+):!git://$1/!;
            
            # Changed
            # I prefer http://github.com/fayland/dist-zilla-plugin-repository
            #   than git://github.com/fayland/dist-zilla-plugin-repository.git 
            if ( $git_url =~ /^git:\/\/(github\.com.*?)\.git$/ ) {
                $git_url = "http://$1/tree";
            }
            
            return $git_url;
        } elsif (`git svn info` =~ /URL: (.*)$/m) {
            return $1;
        }
    } elsif (-e ".svn") {
        if (`svn info` =~ /URL: (.*)$/m) {
            return $1;
        }
    } elsif (-e "_darcs") {
        # defaultrepo is better, but that is more likely to be ssh, not http
        if (my $query_repo = `darcs query repo`) {
            if ($query_repo =~ m!Default Remote: (http://.+)!) {
                return $1;
            }
        }

        open my $handle, '<', '_darcs/prefs/repos' or return;
        while (<$handle>) {
            chomp;
            return $_ if m!^http://!;
        }
    } elsif (-e "$ENV{HOME}/.svk") {
        # Is there an explicit way to check if it's an svk checkout?
        my $svk_info = `svk info` or return;
        SVK_INFO: {
            if ($svk_info =~ /Mirrored From: (.*), Rev\./) {
                return $1;
            }

            if ($svk_info =~ m!Merged From: (/mirror/.*), Rev\.!) {
                $svk_info = `svk info /$1` or return;
                redo SVK_INFO;
            }
        }

        return;
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
