unit module MothTrap::Container;

use MothTrap::Exceptions::NotFoundException;
use MothTrap::Exceptions::CyclicalDependencyException;

class Container is export {
    has %!bindings;

    multi method set(Str $abstract, Callable $factory) {
        %!bindings{$abstract} = $factory;
    }

    multi method set(Str $abstract, Mu $value) {
        %!bindings{$abstract} = $value;
    }

    method has(Str $abstract --> Bool) {
        %!bindings{$abstract}:exists;
    }

    method get($abstract) {
        if self.has($abstract.^name) {
            return %!bindings{$abstract.^name}(self);
        }

        my $instance = self.produce($abstract);
        %!bindings{$abstract.^name} = $instance;
        
        return $instance;
    }

    method produce($abstract) {
        my @dependencies = self!build-dependencies($abstract);
        return $abstract.new(|@dependencies);
    }

    method !build-dependencies($abstract) {
        my $meta = $abstract.HOW;
        my $build-method = $meta.find_method($abstract, 'new');
        my $signature = $build-method.signature;

        my @deps;
        for $signature.params -> $param {
            if $param.name and $param.type ~~ $abstract {
                die CyclicalDependencyException.new(message => "'$param.type' cannot use self as dependency");
            }
            
            if $param.type ~~ Any {
                die Moth::NotFoundException.new(message => "'$param.name' must have a type that is not 'Any'");
            }
            
            if $param.name and not $param.name ~~ '%_'  {
                @deps.push(self.get($param.type));
            }
        }
        
        return @deps;
    }
}
