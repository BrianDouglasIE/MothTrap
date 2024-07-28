# MothTrap

MothTrap is a Dependency Injection Container, with autowiring, for Raku.

## Installation

Before using MothTrap in your project, add it to your `META6.json`
file:

``` bash
$
```

## Usage

Creating a container is a matter of creating a `MothTrap::Container` instance:

``` raku
use MothTrap::Container;

my $container = MothTrap::Container.new;
```

As with many other dependency injection containers, MothTrap manages two
different kind of data: **services** and **parameters**.

### Defining Services

A service is an object that does something as part of a larger system.
Examples of services: a database connection, a templating engine, or a
mailer. Almost any **global** object can be a service.

Services are defined by **anonymous functions** that return an instance
of an object:

``` raku
# define some services
$container.set('session_storage', -> Container $c { SessionStorage.new('SESSION_ID')) });

$container.set('session', -> Container $c { Session.new($c.get('session_storage'))) });
```

Notice that the anonymous function has access to the current container
instance, allowing references to other services or parameters.

As objects are only created when you get them, the order of the
definitions does not matter.

Using the defined services is also very easy:

``` raku
# get the session object
$session = $container.get('session');

# the above call is roughly equivalent to the following code:
# $storage = SessionStorage.new('SESSION_ID');
# $session = new Session.new($storage);
```

### MothTrap as a Service Factory

Each time you `get` a service, MothTrap returns the **same
instance** of it. If you want a different instance to be returned you can
call the `produce` method. This will return a new instance of the 
requested service.

``` raku
$container.produce('session'); # returns new instance of session
$container.get('session'); # returns a cached instance of session
```

### Defining Parameters

Defining a parameter allows to ease the configuration of your container
from the outside and to store global values:

``` raku
# define some parameters
$container.set('cookie_name', 'SESSION_ID');
$container.set('session_storage_class', 'SessionStorage');
```

If you change the `session_storage` service definition like below:

``` raku
$container.set('session_storage', -> Container $c { 
    $c.get('session_storage_class').new($c.get('cookie_name'));
});
```

You can now easily change the cookie name by overriding the
`cookie_name` parameter instead of redefining the service definition.

### Protecting Parameters

Because MothTrap sees anonymous functions as service definitions, you need
to wrap anonymous functions with the `protect` method to store them as
parameters:

``` raku
# $container['random_func'] = $container->protect(fn() => rand());
```

### Modifying Services after Definition

In some cases you may want to modify a service definition after it has
been defined. You can use the `extend` method to define additional
code to be run on your service just after it is created:

``` raku
# $container['session_storage'] = fn($c) => new $c['session_storage_class']($c['cookie_name']);
# 
# $container->extend('session_storage', function ($storage, $c) {
#     $storage->...();
# 
#     return $storage;
# });
```

The first argument is the name of the service to extend, the second a
function that gets access to the object instance and the container.

### Fetching the Service Creation Function

When you access an object, MothTrap automatically calls the anonymous
function that you defined, which creates the service object for you. If
you want to get raw access to this function, you can use the `raw`
method:

``` raku
# $container['session'] = fn($c) => new Session($c['session_storage']);
# 
# $sessionFunction = $container->raw('session');
```
