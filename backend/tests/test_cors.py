def test_cors_header_present_for_browser_requests(client):
    response = client.options(
        "/predict_interval",
        headers={
            "Origin": "http://localhost:12345",
            "Access-Control-Request-Method": "POST",
        },
    )
    assert response.headers.get("access-control-allow-origin") == "*"
