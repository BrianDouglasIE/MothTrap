use lib './lib';
use MothTrap::Container;

class Logger {
    method log(Str $text) {
        say $text;
    }
}

class SessionStorage {
    has Logger $!logger;

    method new(Logger $logger) {
        self.bless(:$logger);
    }

    method create() {
        $!logger.log('Session Created');
    }
}

class User {
    has SessionStorage $.session;

    method new(SessionStorage $session) {
        self.bless(:$session);
    }

    method authenticate() {
        $.session.create();
    }
}

CATCH {
    default {
        say "An error occurred: $_";
        exit 1;
    }
}

my $container = Container.new;

my $user = $container.get(User);
$user.authenticate();

