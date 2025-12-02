class BaseAasm < AASM::Base
  def log_transitions!
    klass.class_eval do
      aasm with_klass: BaseAasm do
        after_all_transitions :log_transitions
      end
    end
  end

  # A custom annotation that we want available across many AASM models.
  def requires_guards!
    klass.class_eval do
      def log_transitions
        Transition.create!(event: aasm.current_event, from_state: aasm.from_state, to_state: aasm.to_state, resource: self)
      end
    end
  end
end
