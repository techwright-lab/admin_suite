# Actions

AdminSuite supports three action “shapes” in the resource DSL:

- `action` (member action on a single record)
- `bulk_action` (runs across selected records)
- `collection_action` (runs on a scope / collection)

## Defining actions

```ruby
actions do
  action :reindex, label: "Reindex", method: :post, confirm: "Reindex this record?"
  bulk_action :archive, label: "Archive", confirm: "Archive selected records?"
end
```

Supported action options:

- `method:` HTTP method (default `:post`)
- `label:` button label (default is humanized action name)
- `icon:` lucide icon name (optional)
- `color:` (optional)
- `confirm:` string confirmation (optional)
- `type:` reserved (default `:button`)
- `if:` Proc condition (member actions only)
- `unless:` Proc condition (member actions only)

## How actions execute

When you trigger an action, AdminSuite resolves behavior in this order:

1. **Model method**: if the target responds to `action_name`, it calls that method.
2. **Bang model method**: else if it responds to `action_name!`, it calls that.
3. **Action handler class**: else it tries to find a handler class.

### Handler class naming convention

By default, AdminSuite looks for:

```ruby
Admin::Actions::<ResourceName><ActionName>Action
```

Example for `UserResource` + `:reset_password`:

```ruby
Admin::Actions::UserResetPasswordAction
```

Handlers should inherit from `Admin::Base::ActionHandler`:

```ruby
# app/admin/actions/user_reset_password_action.rb
module Admin
  module Actions
    class UserResetPasswordAction < Admin::Base::ActionHandler
      def call
        # record is available as `record`, actor as `actor`, request params as `params`
        record.send_reset_password_instructions!
        success "Reset email sent."
      rescue StandardError => e
        failure "Failed to send reset: #{e.message}"
      end
    end
  end
end
```

## Overriding handler resolution (`config.resolve_action_handler`)

If your app doesn’t want to follow the default naming convention, you can provide a resolver:

```ruby
AdminSuite.configure do |config|
  config.resolve_action_handler = ->(resource_class, action_name) do
    # return a Class or nil
    if resource_class.name == "Admin::Resources::UserResource" && action_name.to_sym == :reset_password
      Admin::Actions::UserResetPasswordAction
    end
  end
end
```

## Auditing hook (`config.on_action_executed`)

You can record or log all actions after they run:

```ruby
AdminSuite.configure do |config|
  config.on_action_executed = ->(actor:, action_name:, resource_class:, subject:, params:, result:) do
    Rails.logger.info(
      "[admin_suite] actor=#{actor&.id} action=#{resource_class.name}##{action_name} success=#{result.success?}"
    )
  end
end
```

