# Kanban Board Design for Interview Applications

## Pipeline Stages (Kanban Columns)

The Kanban board will display applications grouped by `pipeline_stage`:

### 1. **Applied** 📝
- Just submitted application
- Waiting for response
- **Card shows:**
  - Company name + logo
  - Job role
  - Applied date
  - Application status badge

### 2. **Screening** 📞
- Initial screening call scheduled/completed
- Recruiter contact stage
- **Card shows:**
  - Company + role
  - Next screening round date (if scheduled)
  - Completed screening rounds count
  - Status: "Scheduled for [date]" or "Awaiting feedback"

### 3. **Interviewing** 💼
- Active interview rounds in progress
- Multiple technical/behavioral rounds
- **Card shows:**
  - Company + role
  - Interview rounds progress (e.g., "3/5 rounds completed")
  - Next interview date
  - Latest round result indicator
  - Timeline preview (collapsed)

### 4. **Offer** 🎉
- Received offer or in offer negotiation
- Final stages
- **Card shows:**
  - Company + role
  - Offer details (if available)
  - Decision deadline
  - Salary range (if entered)

### 5. **Closed** ✅❌
- Application completed (accepted or rejected)
- Archived applications
- **Card shows:**
  - Company + role
  - Final outcome (Accepted/Rejected)
  - Closure date
  - Key takeaways/feedback summary

## Kanban Card Structure

```
┌─────────────────────────────────────┐
│ [Company Logo] Company Name         │
│ Job Role Title                      │
├─────────────────────────────────────┤
│ 📅 Next: Technical Interview        │
│    Tomorrow at 2:00 PM              │
│                                     │
│ ✓ Screening (Passed)                │
│ ⏳ Technical Round 1 (Pending)      │
│                                     │
│ 💡 3 skills matched                 │
├─────────────────────────────────────┤
│ [View Details] [Add Feedback]       │
└─────────────────────────────────────┘
```

## Card Actions (Inline)

Each card will have quick actions:
- **Drag & Drop** - Move between pipeline stages
- **Add Round** - Quick add new interview round
- **Add Feedback** - Add feedback for latest round
- **View Timeline** - Expand to see full timeline
- **Archive** - Move to closed

## Status vs Pipeline Stage

### Status (Application-level)
- `active` - Currently pursuing this opportunity
- `archived` - No longer pursuing (user chose to stop)
- `rejected` - Company rejected the application
- `accepted` - Offer accepted

### Pipeline Stage (Process-level)
- `applied` - Just applied
- `screening` - In screening phase
- `interviewing` - In interview rounds
- `offer` - Offer stage
- `closed` - Process complete

### Relationship
```
Status: Active + Pipeline: Applied → Show in "Applied" column
Status: Active + Pipeline: Interviewing → Show in "Interviewing" column
Status: Rejected + Pipeline: * → Show in "Closed" column (with rejected badge)
Status: Accepted + Pipeline: Closed → Show in "Closed" column (with accepted badge)
Status: Archived + Pipeline: * → Show in "Closed" column (with archived badge)
```

## Automatic Stage Transitions

The system can auto-update `pipeline_stage` based on events:

1. **Applied → Screening**
   - When first interview round with stage=screening is created

2. **Screening → Interviewing**
   - When first non-screening interview round is created
   - Or when screening round is marked as passed

3. **Interviewing → Offer**
   - Manually moved by user
   - Or when company_feedback indicates offer

4. **Any → Closed**
   - When status changes to rejected/accepted/archived
   - Or when user manually closes

## View Options

### Kanban View (Default)
- 5 columns (pipeline stages)
- Cards sorted by: next_action_date, then created_at
- Drag and drop between columns
- Collapsible columns

### List View (Alternative)
- Table format with all applications
- Filterable by pipeline_stage, status, company, role
- Sortable by any column
- Bulk actions available

## Card Badges & Indicators

- 🔴 **Urgent** - Interview scheduled within 24 hours
- 🟡 **Pending** - Awaiting feedback/response > 1 week
- 🟢 **Active** - Recent activity
- 📊 **Progress** - "3/5 rounds" indicator
- ⏰ **Scheduled** - Next interview date
- 💬 **Feedback** - Has company feedback

## Example Kanban Board

```
┌─────────────┬─────────────┬─────────────┬─────────────┬─────────────┐
│   Applied   │  Screening  │Interviewing │    Offer    │   Closed    │
│     (5)     │     (3)     │     (8)     │     (2)     │    (12)     │
├─────────────┼─────────────┼─────────────┼─────────────┼─────────────┤
│             │             │             │             │             │
│ Google      │ Meta        │ Stripe      │ Netflix     │ Amazon      │
│ Senior SWE  │ Staff Eng   │ Senior SWE  │ Principal   │ Senior SWE  │
│ 2 days ago  │ Screen tmrw │ 3/4 rounds  │ Offer recv  │ ✅ Accepted │
│             │             │ Next: Fri   │ $250k       │             │
│             │             │             │             │             │
│ Apple       │ Uber        │ Airbnb      │ Shopify     │ Twitter     │
│ Staff Eng   │ Senior SWE  │ Senior SWE  │ Lead Eng    │ ❌ Rejected │
│ 1 week ago  │ Passed      │ 2/3 rounds  │ Negotiating │             │
│             │             │             │             │             │
└─────────────┴─────────────┴─────────────┴─────────────┴─────────────┘
```

## Implementation Notes

### Controller
```ruby
# app/controllers/interview_applications_controller.rb
def index
  @applications = current_user.interview_applications
                              .includes(:company, :job_role, :interview_rounds)
                              .active
  
  if params[:view] == 'kanban'
    @applications_by_stage = @applications.group_by(&:pipeline_stage)
  else
    @applications = @applications.recent
  end
end
```

### View
```erb
<!-- Kanban View -->
<% InterviewApplication::PIPELINE_STAGES.each do |stage| %>
  <div class="kanban-column" data-stage="<%= stage %>">
    <h3><%= stage.to_s.humanize %> (<%= @applications_by_stage[stage]&.count || 0 %>)</h3>
    
    <% (@applications_by_stage[stage] || []).each do |application| %>
      <%= render 'application_card', application: application %>
    <% end %>
  </div>
<% end %>
```

### Drag & Drop (Stimulus)
```javascript
// app/javascript/controllers/kanban_controller.js
updateStage(event) {
  const applicationId = event.item.dataset.applicationId
  const newStage = event.to.dataset.stage
  
  fetch(`/interview_applications/${applicationId}/update_pipeline_stage`, {
    method: 'PATCH',
    body: JSON.stringify({ pipeline_stage: newStage })
  })
}
```

## Benefits of This Design

1. **Clear Visual Progress** - See where each application stands at a glance
2. **Multiple Rounds Support** - Each card can show progress through many interview rounds
3. **Flexible** - Can have 10 applications in "Interviewing" with different round counts
4. **Actionable** - Quick actions on each card
5. **Timeline Ready** - Click card to see detailed timeline of all rounds
6. **Filterable** - Can filter by status within each column
7. **Drag & Drop** - Easy to move applications between stages

