unit module MothTrap::Exceptions::CyclicalDependencyException;

class CyclicalDependencyException is Exception {
    has $.message;

    method message() {
        $.message // "Cyclical Dependency Found"
    }
}