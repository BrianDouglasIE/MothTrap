# MothContainer

MothContainer is a small Dependency Injection Container for Raku.

## Installation

Before using MothContainer in your project, add it to your `composer.json`
file:

``` bash
$ ./composer.phar require pimple/pimple "^3.0"
```

## Usage

Creating a container is a matter of creating a `MothContainer` instance:

``` raku
need Moth::Container;

my $container = Container::Container.new;
```

As many other dependency injection containers, MothContainer manages two
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

### MothContainer as a Service Factory

Each time you `get` a service, MothContainer returns the **same
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

Because Pimple sees anonymous functions as service definitions, you need
to wrap anonymous functions with the `protect()` method to store them as
parameters:

``` php
$container['random_func'] = $container->protect(fn() => rand());
```

### Modifying Services after Definition

In some cases you may want to modify a service definition after it has
been defined. You can use the `extend()` method to define additional
code to be run on your service just after it is created:

``` php
$container['session_storage'] = fn($c) => new $c['session_storage_class']($c['cookie_name']);

$container->extend('session_storage', function ($storage, $c) {
    $storage->...();

    return $storage;
});
```

The first argument is the name of the service to extend, the second a
function that gets access to the object instance and the container.

### Extending a Container

If you use the same libraries over and over, you might want to reuse
some services from one project to the next one; package your services
into a **provider** by implementing `Pimple\ServiceProviderInterface`:

``` php
use Pimple\Container;

class FooProvider implements Pimple\ServiceProviderInterface
{
    public function register(Container $pimple)
    {
        // register some services and parameters
        // on $pimple
    }
}
```

Then, register the provider on a Container:

``` php
$pimple->register(new FooProvider());
```

### Fetching the Service Creation Function

When you access an object, Pimple automatically calls the anonymous
function that you defined, which creates the service object for you. If
you want to get raw access to this function, you can use the `raw()`
method:

``` php
$container['session'] = fn($c) => new Session($c['session_storage']);

$sessionFunction = $container->raw('session');
```

## PSR-11 compatibility

For historical reasons, the `Container` class does not implement the
PSR-11 `ContainerInterface`. However, Pimple provides a helper class
that will let you decouple your code from the Pimple container class.

### The PSR-11 container class

The `Pimple\Psr11\Container` class lets you access the content of an
underlying Pimple container using `Psr\Container\ContainerInterface`
methods:

``` php
use Pimple\Container;
use Pimple\Psr11\Container as PsrContainer;

$container = new Container();
$container['service'] = fn($c) => new Service();
$psr11 = new PsrContainer($container);

$controller = function (PsrContainer $container) {
    $service = $container->get('service');
};
$controller($psr11);
```

### Using the PSR-11 ServiceLocator

Sometimes, a service needs access to several other services without
being sure that all of them will actually be used. In those cases, you
may want the instantiation of the services to be lazy.

The traditional solution is to inject the entire service container to
get only the services really needed. However, this is not recommended
because it gives services a too broad access to the rest of the
application and it hides their actual dependencies.

The `ServiceLocator` is intended to solve this problem by giving access
to a set of predefined services while instantiating them only when
actually needed.

It also allows you to make your services available under a different
name than the one used to register them. For instance, you may want to
use an object that expects an instance of `EventDispatcherInterface` to
be available under the name `event_dispatcher` while your event
dispatcher has been registered under the name `dispatcher`:

``` php
use Monolog\Logger;
use Pimple\Psr11\ServiceLocator;
use Psr\Container\ContainerInterface;
use Symfony\Component\EventDispatcher\EventDispatcher;

class MyService
{
    /**
     * "logger" must be an instance of Psr\Log\LoggerInterface
     * "event_dispatcher" must be an instance of Symfony\Component\EventDispatcher\EventDispatcherInterface
     */
    private $services;

    public function __construct(ContainerInterface $services)
    {
        $this->services = $services;
    }
}

$container['logger'] = fn($c) => new Monolog\Logger();
$container['dispatcher'] = fn($c) => new EventDispatcher();

$container['service'] = function ($c) {
    $locator = new ServiceLocator($c, array('logger', 'event_dispatcher' => 'dispatcher'));

    return new MyService($locator);
};
```

### Referencing a Collection of Services Lazily

Passing a collection of services instances in an array may prove
inefficient if the class that consumes the collection only needs to
iterate over it at a later stage, when one of its method is called. It
can also lead to problems if there is a circular dependency between one
of the services stored in the collection and the class that consumes it.

The `ServiceIterator` class helps you solve these issues. It receives a
list of service names during instantiation and will retrieve the
services when iterated over:

``` php
use Pimple\Container;
use Pimple\ServiceIterator;

class AuthorizationService
{
    private $voters;

    public function __construct($voters)
    {
        $this->voters = $voters;
    }

    public function canAccess($resource)
    {
        foreach ($this->voters as $voter) {
            if (true === $voter->canAccess($resource)) {
                return true;
            }
        }

        return false;
    }
}

$container = new Container();

$container['voter1'] = fn($c) => new SomeVoter();
$container['voter2'] = fn($c) => new SomeOtherVoter($c['auth']);
$container['auth'] = fn ($c) => new AuthorizationService(new ServiceIterator($c, array('voter1', 'voter2'));
```
