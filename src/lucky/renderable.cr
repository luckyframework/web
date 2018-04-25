module Lucky::Renderable
  # Create a page for an action to display
  #
  # `render` takes two arguments, a `page_class` and data to send to the page.
  # The `page_class` is automatically extracted from the action. For example,
  # the `Users::Index` action is converted into `Users::IndexPage`. You can
  # also pass a page class directly if you need to. For example the
  # `Users::Search` action can render the `Users::IndexPage`:
  #
  # ```crystal
  # class Users::Search < BrowserAction
  #   action do
  #     # search for users
  #
  #     render Users::IndexPage, users: user_search_results
  #   end
  # end
  # ```
  #
  # The second argument to `render` is used to pass data to the page. Each
  # key/value pair must match up with the `needs` declarations for the page.
  # For example, if we have a page like this:
  #
  # ```crystal
  # class Users::IndexPage < MainLayout
  #   needs users : UserQuery
  #
  #   def content
  #     @users.each do |user|
  #       # ...
  #     end
  #   end
  # end
  # ```
  #
  # Our action must use pass a `users` key to the `render` method like this:
  #
  # ```crystal
  # class Users::Index < BrowserAction
  #   action do
  #     render users: UserQuery.new
  #   end
  # end
  # ```
  macro render(page_class = nil, **assigns)
    render_html_page(
      {{ page_class || "#{@type.name}Page".id }},
      {% if assigns.empty? %}
        {} of String => String
      {% else %}
        {{ assigns }}
      {% end %}
    )
  end

  # :nodoc:
  macro render_html_page(page_class, assigns)
    view = {{ page_class.id }}.new(
      context: context,
      {% for key, value in assigns %}
        {{ key }}: {{ value }},
      {% end %}
      {% exposed = EXPOSURES.reject { |exposure| UNEXPOSED.includes?(exposure) } %}
      {% for key in exposed %}
        {{ key }}: {{ key }},
      {% end %}
    )
    body = view.perform_render.to_s
    Lucky::Response.new(
      context,
      "text/html",
      body,
      debug_message: log_message(view),
    )
  end

  private def log_message(view)
    "Rendered #{view.class.colorize(HTTP::Server::Context::DEBUG_COLOR)}"
  end

  # :nodoc:
  def perform_action
    response = call
    handle_response(response)
  end

  private def handle_response(response : Lucky::Response)
    log_response(response)
    response.print
  end

  private def handle_response(_response : T) forall T
    {%
      raise <<-ERROR

      #{@type} returned #{T}, but it must return a Lucky::Response.

      Try this...
        ▸ Make sure to use a method like `render`, `redirect`, or `json` at the end of your action.
        ▸ If you are using a conditional, make sure all branches return a Lucky::Response.
      ERROR
    %}
  end

  private def log_response(response : Lucky::Response)
    response.debug_message.try do |message|
      context.add_debug_message(message)
    end
  end

  private def text(body, status : Int32? = nil)
    Lucky::Response.new(context, "text/plain", body, status: status)
  end

  private def text(body, status : Lucky::Action::Status)
    Lucky::Response.new(context, "text/plain", body, status: status.value)
  end

  private def render_text(*args, **named_args)
    text(*args, **named_args)
  end

  private def head(status : Int32)
    Lucky::Response.new(context, content_type: "", body: "", status: status)
  end

  private def head(status : Lucky::Action::Status)
    head(status.value)
  end

  private def json(body, status : Int32? = nil)
    Lucky::Response.new(context, "application/json", body.to_json, status)
  end

  private def json(body, status : Lucky::Action::Status = nil)
    json(body, status.value)
  end
end
