unit module MothTrap::Exceptions::NotFoundException;

class NotFoundException is Exception {
    has $.message;

    method message() {
        $.message // "Not Found"
    }
}