package Dist::Zilla::Plugin::Repository;

# ABSTRACT: Automatically sets repository URL from svn/svk/Git checkout for Dist::Zilla

use Moose;
use Moose::Autobox;
with 'Dist::Zilla::Role::InstallTool';

use Dist::Zilla::File::InMemory;

=head1 SYNOPSIS
 
    # dist.ini
    [Repository]

=head1 DESCRIPTION

The code is mostly a copy-paste of L<Module::Install::Repository>
 
=cut

sub setup_installer {
    my ($self, $arg) = @_;

    # check if [MetaYaml] is there
    my $has_metayml = $self->zilla->plugins
        ->grep(sub { ref $_ eq 'Dist::Zilla::Plugin::MetaYaml' })->length;
    if ( $has_metayml ) {
        
        my $repo = _find_repo();
        unless ($repo) {
            $self->zilla->log("[Repository] Cannot determine repository URL");
            return 0;
        }
        
        my $file = $self->zilla->files
             ->grep(sub { $_->name =~ m{META\.yml\z} })
             ->head;
        
        if ( $file ) {
            my $content = $file->content;
            require YAML::Syck;
            my $meta = YAML::Syck::Load($content);
            $meta->{resources}{repository} = $repo;
            $file->content( YAML::Syck::Dump($meta) );
        } else {
            $self->zilla->log("[Repository] Skip META.yml ([Repository] needs after [MetaYaml]");
        }
    }

    return;
}

# Copy-Paste of Module-Install-Repository, thank MIYAGAWA
sub _find_repo {
    if (-e ".git") {
        # TODO support remote besides 'origin'?
        if (`git remote show origin` =~ /URL: (.*)$/m) {
            # XXX Make it public clone URL, but this only works with github
            my $git_url = $1;
            $git_url =~ s![\w\-]+\@([^:]+):!git://$1/!;
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
