##############################################################################
package JSON::RPC::Server::Daemon;

use strict;
use JSON::RPC::Server; # for old Perl 5.005
use base qw(JSON::RPC::Server);

$JSON::RPC::Server::Daemon::VERSION = '0.02';

use Data::Dumper;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new();
    my $pkg;

    if(  grep { $_ =~ /^SSL_/ } @_ ){
        $self->{_daemon_pkg} = $pkg = 'HTTP::Daemon::SSL';
    }
    else{
        $self->{_daemon_pkg} = $pkg = 'HTTP::Daemon';
    }
    eval qq| require $pkg; |;
    if($@){ die $@ }

    $self->{_daemon} ||= $pkg->new(@_) or die;

    return $self;
}


sub handle {
    my $self = shift;
    my %opt  = @_;
    my $d    = $self->{_daemon} ||= $self->{_daemon_pkg}->new(@_) or die;

    while (my $c = $d->accept) {
        $self->{con} = $c;
        while (my $r = $c->get_request) {
            $self->request($r);
            $self->path_info($r->url->path);
            $self->SUPER::handle();
            last;
        }
        $c->close;
    }

}


sub retrieve_json_from_post {
    return $_[0]->request->content;
}


sub retrieve_json_from_get {
}


sub response {
    my ($self, $response) = @_;
    $self->{con}->send_response($response);
}

1;
__END__
