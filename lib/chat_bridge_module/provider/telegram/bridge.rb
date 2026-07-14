# frozen_string_literal: true
# Telegram  ---> Discourse
%i[message edited_message].each do |event|
  ::ChatBridgeModule::Provider::Telegram::TelegramEvent.on(event) do |message|
    next unless SiteSetting.chat_bridge_enabled && SiteSetting.chat_enabled

    Scheduler::Defer.later("Bridge a telegram #{event} to discourse") do
      result =
        ::ChatBridgeModule::Provider::Telegram::Services::HandleTgMessage.call(
          params: {
            message:,
            edit: event == :edited_message,
          },
        )

      if result.failure?
        begin
          Rails.logger.error(<<~TEXT)
            [Telegram Bridge] Failed to bridge message:
            #{result.inspect_steps}
            TEXT
        rescue => e
          STDERR.puts "[Telegram Bridge] Failed to bridge message: \n#{result.inspect_steps} (Logging error: #{e.message})"
        end
      end
    end
  end
end

# Discourse ---> Telegram
%i[chat_message_created chat_message_edited chat_message_trashed].each do |event|
  DiscourseEvent.on(event) do |message, channel, user| # rubocop:disable Discourse/Plugins/UsePluginInstanceOn
    next unless SiteSetting.chat_bridge_enabled && SiteSetting.chat_enabled

    puts <<~TEXT


    ========================================
      Discourse --> Telegram
    ========================================



    TEXT

    Scheduler::Defer.later("Bridge #{event} to telegram") do
      result =
        ::ChatBridgeModule::Provider::Telegram::Services::HandleDiscourseMessage.call(
          params: {
            message:,
            channel:,
            user:,
            event:,
          },
        )
      if result.failure? && !%w[BRIDGE_BACK INVALID_BOT].any? { |reason| result.inspect_steps.to_s.include?(reason) }
        begin
          Rails.logger.warn("[Discourse -> Telegram] Failed in #{event}: \n#{result.inspect_steps}")
        rescue => e
          STDERR.puts "[Discourse -> Telegram] Failed in #{event}: \n#{result.inspect_steps} (Logging error: #{e.message})"
        end
      end
    end
  end
end
