module RequestSpecHelper
  # Generate token for test
  def token_generator(user_id)
    JsonWebToken.encode(user_id: user_id)
  end

  # Generate expired token
  def expired_token_generator(user_id)
    JsonWebToken.encode({ user_id: user_id }, Time.now - 10)
  end

  # Return valid headers
  def valid_headers(user_id)
    {
      "Authorization" => token_generator(user_id),
      "Content-Type" => "application/json"
    }
  end

  # Return invalid headers
  def invalid_headers
    {
      "Authorization" => nil,
      "Content-Type" => "application/json"
    }
  end
end