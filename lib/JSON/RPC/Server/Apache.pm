##############################################################################
package JSON::RPC::Server::Apache;

use strict;

use lib qw(/var/www/cgi-bin/json/);
use base qw(JSON::RPC::Server);

use Apache2::Const qw(OK HTTP_BAD_REQUEST SERVER_ERROR);

use APR::Table ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();


$JSON::RPC::Server::Apache::VERSION = '0.03';


sub handler {
    my($r) = @_;

    my $s = __PACKAGE__->new;

    $s->request($r);

    $s->{path_info} = $r->path_info;

    my @modules = $r->dir_config('dispatch') || $r->dir_config('dispatch_to');

    $s->dispatch([@modules]);

    $s->handle(@_);

    Apache2::Const::OK;
}


sub new {
    my $class = shift;
    return $class->SUPER::new();
}


sub retrieve_json_from_post {
    my $self = shift;
    my $r    = $self->request;
    my $len  = $r->headers_in()->get('Content-Length');

    return if($r->method ne 'POST');
    return if($len > $self->max_length);

    my ($buf, $content);

    while( $r->read($buf,$len) ){
        $content .= $buf;
    }

    $content;
}


sub retrieve_json_from_get {
    my $self = shift;
    my $r    = $self->request;
    my $args = $r->args;

    $args = '' if (!defined $args);

    $self->{path_info} = $r->path_info;

    my $params = {};

    $self->version(1.1);

    for my $pair (split/&/, $args) {
        my ($key, $value) = split/=/, $pair;
        if ( defined ( my $val = $params->{ $key } ) ) {
            if ( ref $val ) {
                push @{ $params->{ $key } }, $value;
            }
            else { # change a scalar into an arrayref
                $params->{ $key } = [];
                push @{ $params->{ $key } }, $val, $value;
            }
        }
        else {
            $params->{ $key } = $value;
        }
    }

    my $method = $r->path_info;

    $method =~ s{^.*/}{};
    $self->{path_info} =~ s{/?[^/]+$}{};

    $self->json->encode({
        version => '1.1',
        method  => $method,
        params  => $params,
    });
}


sub response {
    my ($self, $response) = @_;
    my $r = $self->request;

    $r->content_type($self->content_type);
    $r->print($response->content);

    return ($response->code == 200)
            ? Apache2::Const::OK : Apache2::Const::SERVER_ERROR;
}



1;
__END__
