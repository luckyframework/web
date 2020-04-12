require "../spec_helper"

include ContextHelper

describe Lucky::SessionHandler do
  it "sets a cookie" do
    context = build_context
    context.cookies.set(:email, "test@example.com")

    Lucky::SessionHandler.new.call(context)

    context.response.headers.has_key?("Set-Cookie").should be_true
    context.response.headers["Set-Cookie"].should contain("email=")
  end

  it "persist cookies across multiple requests using response headers from Lucky and request headers from the browser" do
    context_1 = build_context
    context_1.cookies.set(:email, "test@example.com")
    Lucky::SessionHandler.new.call(context_1)

    browser_request = build_request
    cookie_header = context_1.response.cookies.map do |cookie|
      cookie.to_cookie_header
    end.join(", ")
    browser_request.headers.add("Cookie", cookie_header)
    context_2 = build_context("/", request: browser_request)

    context_2.cookies.get(:email).should eq "test@example.com"
  end

  it "only writes updated cookies to the response" do
    request = build_request
    # set initial cookies via header
    request.headers.add("Cookie", "cookie1=value1; cookie2=value2")
    context = build_context("/", request: request)
    context.cookies.set_raw(:cookie2, "updated2")

    Lucky::SessionHandler.new.call(context)

    context.response.headers["Set-Cookie"].should contain("cookie2=updated2")
    context.response.headers["Set-Cookie"].should_not contain("cookie1")
  end

  it "sets a session" do
    context = build_context
    context.session.set(:email, "test@example.com")

    Lucky::SessionHandler.new.call(context)

    context.response.headers.has_key?("Set-Cookie").should be_true
    context.response.headers["Set-Cookie"].should contain("_app_session")
  end

  it "persists the session across multiple requests" do
    context_1 = build_context
    context_1.session.set(:email, "test@example.com")
    Lucky::SessionHandler.new.call(context_1)

    request = build_request
    cookie_header = context_1.response.cookies.map do |cookie|
      cookie.to_cookie_header
    end.join("; ")
    request.headers.add("Cookie", cookie_header)
    context_2 = build_context("/", request: request)
    Lucky::SessionHandler.new.call(context_2)

    context_2.session.get(:email).should eq("test@example.com")
  end

  it "writes all the proper headers when a cookie is set" do
    context = build_context
    context
      .cookies
      .set(:yo, "lo")
      .path("/awesome")
      .expires(Time.utc(2000, 1, 1))
      .domain("luckyframework.org")
      .secure(true)
      .http_only(true)

    Lucky::SessionHandler.new.call(context)

    header = context.response.headers["Set-Cookie"]
    header.should contain("path=/awesome")
    header.should contain("expires=Sat, 01 Jan 2000")
    header.should contain("domain=luckyframework.org")
    header.should contain("Secure")
    header.should contain("HttpOnly")
  end
end
