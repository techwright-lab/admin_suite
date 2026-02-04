# Fields

Fields are defined in the resource `form do ... end` block:

```ruby
form do
  field :name
  field :status, type: :select, collection: [["Active", "active"], ["Inactive", "inactive"]]
end
```

## Common options

All fields support:

- `type:` (defaults to `:text`)
- `required:` (`true/false`)
- `label:` (String)
- `help:` (String)
- `placeholder:` (String)
- `readonly:` (`true/false`)
- `if:` Proc (render only if truthy)
- `unless:` Proc (render only if falsy)

Example conditional field:

```ruby
field :admin_notes, type: :textarea, if: ->(record) { record.admin? }
```

## Supported field types

### Text-like

- `:text` (default)
- `:textarea` (`rows:` supported)
- `:email`
- `:url`
- `:number`
- `:date`
- `:time`
- `:datetime`

### Toggle

- `:toggle` (renders a switch)

```ruby
field :enabled, type: :toggle
```

### Select

- `:select` (uses Rails `select`)

Options:

- `collection:` Array of `[label, value]` or simple values

```ruby
field :status, type: :select, collection: [["Active", "active"], ["Inactive", "inactive"]]
```

### Searchable select

- `:searchable_select` (Stimulus-powered searchable dropdown)

Options:

- `collection:` either:
  - an Array (static options), or
  - a String URL (advanced; used by the JS controller as a “search URL”)
- `create_url:` (String) enables “creatable” behavior in the UI

```ruby
field :company_id,
  type: :searchable_select,
  collection: Company.order(:name).pluck(:name, :id),
  placeholder: "Search companies..."
```

### Multi-select & tags

- `:multi_select`
- `:tags`

Options:

- `collection:` Array of options (used for suggestions)
- `create_url:` enables “creatable” behavior
- `multiple:` boolean (reserved; arrays are permitted automatically)

Notes:

- These submit arrays and are permitted automatically by AdminSuite.
- For `:tags`, AdminSuite uses a `tag_list` parameter by default (or `#{field_name}_list` if your model exposes it).

```ruby
field :tag_list, type: :tags, placeholder: "Add tags..."
field :roles, type: :multi_select, collection: %w[admin editor viewer]
```

### File uploads / attachments

- `:file`
- `:attachment`
- `:image`

Options:

- `accept:` MIME accept string (e.g. `"image/*"`, `"application/pdf"`)

These assume your host app uses **Active Storage**.

```ruby
field :avatar, type: :image, accept: "image/*"
field :resume, type: :file, accept: "application/pdf"
```

### Rich text

- `:trix`
- `:rich_text`

These assume your host app uses **Action Text**.

```ruby
field :bio, type: :rich_text
```

### Markdown

- `:markdown` (textarea enhanced by EasyMDE via CDN in the engine layout)

```ruby
field :prompt_template, type: :markdown, rows: 16
```

### JSON editor

- `:json` (renders the engine’s JSON editor partial)

```ruby
field :settings, type: :json
```

### Code editor

- `:code` (monospace editor container; enhanced by engine JS)

```ruby
field :ruby_code, type: :code, rows: 20
```

### Label (read-only)

- `:label` renders a badge-like value (useful for status fields)

Options:

- `label_color:` Symbol or Proc
- `label_size:` `:sm`/`:md` or Proc

```ruby
field :status, type: :label, label_color: ->(r) { r.active? ? :emerald : :slate }, label_size: :sm
```

## Layout helpers

Inside `form do ... end` you can group fields:

### `section`

```ruby
section "Billing", description: "Payment settings", collapsible: true do
  field :stripe_customer_id, readonly: true
end
```

### `row`

```ruby
row cols: 2 do
  field :first_name
  field :last_name
end
```

