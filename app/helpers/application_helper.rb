module ApplicationHelper
  # Returns a time-based greeting message
  #
  # @return [String] Greeting based on current time
  def greeting_message
    hour = Time.current.hour
    case hour
    when 5..11 then "Good morning"
    when 12..16 then "Good afternoon"
    when 17..20 then "Good evening"
    else "Hello"
    end
  end

  # Returns the color class for an email type indicator bar
  #
  # @param email_type [String] The email type
  # @return [String] Tailwind CSS classes for the color
  def email_type_color_class(email_type)
    case email_type&.to_s
    when "offer"
      "bg-emerald-500"
    when "rejection"
      "bg-red-500"
    when "interview_invite"
      "bg-blue-500"
    when "follow_up"
      "bg-amber-500"
    when "confirmation", "application_confirmation"
      "bg-purple-500"
    when "scheduling"
      "bg-cyan-500"
    else
      "bg-gray-300 dark:bg-gray-600"
    end
  end
end
