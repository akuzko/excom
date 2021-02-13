# Excom

Flexible and highly extensible Service Objects for business logic organization.

[![build status](https://secure.travis-ci.org/akuzko/excom.png)](http://travis-ci.org/akuzko/excom)
[![github release](https://img.shields.io/github/release/akuzko/excom.svg)](https://github.com/akuzko/excom/releases)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'excom'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install excom

## Preface

`Excom` stands for **Ex**excutable **Com**and. Initially, `Excom::Command` was the main
class, provided by the gem. But it seems that "Service" name become more popular and
common for describing classes for business logic, so it was renamed in this gem too.

## Usage

General idea behind every `excom` service is simple: each service can have arguments,
options (named arguments), and should define `execute!` method that is called during
service execution. Executed service has `status` and `result`.

The very basic usage of `Excom` services can be shown with following example:

```rb
# app/services/todos/update.rb
module Todos
  class Update < Excom::Service
    attributes :todo, :params

    delegate :errors, to: :todo

    def execute!
      todo.update(params)
    end
  end
end

# app/controllers/todos/controller
class TodosController < ApplicationController
  def update
    service = Todos::Update.new(todo, params: todo_params)

    if service.execute.success?
      render json: Todos::Show.(service.result)
    else
      render json: service.errors, status: service.status
    end
  end
end
```

However, even this basic example can be highly optimized by using Excom extensions and helper methods.

### Service attributes

Read full version on [wiki](https://github.com/akuzko/excom/wiki#instantiating-service-with-attributes).

Excom services are initialized with _attributes_. To specify list of available attributes, use `attributes`
class methods. All attributes are optional during service initialization. It is possible to omit keys during
initialization, and pass attributes as parameters - in this case attributes will be filled in correspondance
to the order they were defined. However, you cannot pass more attributes than declared attributes list, as
well as cannot pass single attribute multiple times (as parameter and as named attribute) or attributes that
were not declared with `attributes` class method.

```rb
class MyService < Excom::Service
  attributes :foo, :bar

  def execute!
    # do something
  end

  def foo
    super || 5
  end
end

s1 = MyService.new
s1.foo # => 5
s1.bar # => nil

s2 = s1.with_attributes(foo: 1, bar: 2)
s2.foo # => 1
s2.bar # => 2
```

### Service Execution

Read full version on [wiki](https://github.com/akuzko/excom/wiki#service-execution).

At the core of each service's execution lies `execute!` method. By default, you can use
`success`, `failure` and `result` methods to set execution status and result. If none
were used, result and status will be set based on `execute!` method's return value.

Example:

```rb
class MyService < Excom::Service
  attributes :foo

  def execute!
    if foo > 2
      success { foo * 2 }
    else
      failure { -1 }
    end
  end
end

service = MyService.new(3)
service.execute.success? # => true
service.result # => 6
```

### Core API

Please read about core API and available class and instance methods on [wiki](https://github.com/akuzko/excom/wiki#core-api)

### Service Extensions (Plugins)

Read full version on [wiki](https://github.com/akuzko/excom/wiki/Plugins).

Excom is built with extensions in mind. Even core functionality is organized in plugins that are
used in base `Excom::Service` class. Bellow you can see a list of plugins with some description
and examples that are shipped with `excom`:

- [`:status`](https://github.com/akuzko/excom/wiki/Plugins#status) - Adds `status` execution state
property to the service, as well as helper methods and behavior to set it. `status` property is not
bound to the "success" flag of execution state and can have any value depending on your needs. It
is up to you to setup which statuses correspond to successful execution and which are not. Generated
status helper methods allow to atomically and more explicitly assign both status and result at
the same time:

```rb
class Posts::Update < Excom::Service
  use :status,
    success: [:ok],
    failure: [:unprocessable_entity]

  attributes :post, :params

  delegate :errors, to: :post

  def execute!
    if post.update(params)
      ok { post.as_json }
    else
      unprocessable_entity
    end
  end
end

service = Posts::Update.(post, post_params)
# in case params were valid you will have:
service.success? # => true
service.status # => :ok
service.result # => {'id' => 1, ...}
```

Note that just like `success`, `failure`, or `result` methods, status helpers accept result value
as result of yielded block.

- [`:context`](https://github.com/akuzko/excom/wiki/Plugins#context) - Allows you to set an execution
context for a block that will be available to any service that uses this plugin via `context` method.

```rb
# application_controller.rb
around_action :with_context

def with_context
  Excom.with_context(current_user: current_user) do
    yield
  end
end
```

```rb
class Posts::Archive < Excom::Service
  use :context

  attributes :post

  def execute!
    post.update(archived: true, archived_by: context[:current_user])
  end
end
```

- [`:abilities`](https://github.com/akuzko/excom/wiki/Plugins#abilities) - Allows you to define permission
checks within a service that can be used in other services for checks and guard violations. Much like
[pundit](https://github.com/elabs/pundit) Policies, but more. Where pundit governs only authorization logic,
Excom's "Ability" services can have any denial reason you find appropriate, and declare logic for
different denial reasons in single place. It also defines `#execute!` method that will result in
hash with all permission checks.

```rb
class Posts::Abilities < Excom::Service
  use :abilities

  attributes :post, :user

  deny_with :unauthorized do
    def publish?
      # only author can publish a post
      post.author_id == user.id
    end

    def delete?
      publish?
    end
  end

  deny_with :unprocessable_entity do
    def delete?
      # disallow to destroy posts that are older than 1 hour
      (post.created_at + 1.hour).past?
    end
  end
end

abilities = Posts::Abilities.new(outdated_post, user)
abilities.can?(:publish)     # => true
abilities.can?(:delete)      # => false
abilities.why_cant?(:delete) # => :unprocessable_entity
abilities.guard!(:delete)    # => raises Excom::Plugins::Abilities::GuardViolationError, :unprocessable_entity
abilities.execute.result     # => {'publish' => true, 'delete' => false}
```

- [`:assertions`](https://github.com/akuzko/excom/wiki/Plugins#assertions) - Provides `assert` method that
can be used for different logic checks during service execution.


- [`:dry_types`](https://github.com/akuzko/excom/wiki/Plugins#dry-types) - Allows you to use
[dry-types](http://dry-rb.org/gems/dry-types/) attributes instead of default `attributes`.

- [`:caching`](https://github.com/akuzko/excom/wiki/Plugins#caching) - Simple plugin that will prevent
re-execution of service if it already has been executed, and will immediately return result.

- [`:rescue`](https://github.com/akuzko/excom/wiki/Plugins#rescue) - Provides `:rescue` execution option.
If set to `true`, any error occurred during service execution will not be raised outside.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/akuzko/excom.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

