def _log_event(client, user_id, **overrides):
    base = {
        "card_id": "c1",
        "lexeme_id": "word1",
        "learning_language": "de",
        "history_seen_before": 2,
        "history_correct_before": 2,
        "delta": 8_640_000,  # 100 days
        "remembered": True,
        "reviewed_at": "2026-09-10T10:00:00",
    }
    base.update(overrides)
    return client.post(f"/log_review/{user_id}", json=base)


def test_no_history_means_no_personalization(client):
    response = client.post(
        "/predict_interval",
        json={"history_seen": 3, "history_correct": 3, "user_id": "user1"},
    )
    assert response.json()["personal_factor"] is None


def test_enough_remembered_longer_than_predicted_raises_factor(client):
    baseline = client.post(
        "/predict_interval",
        json={"history_seen": 3, "history_correct": 3},
    ).json()["half_life_days"]

    for i in range(6):
        resp = _log_event(client, "user1", card_id=f"c{i}")
        assert resp.status_code == 200

    personalized = client.post(
        "/predict_interval",
        json={"history_seen": 3, "history_correct": 3, "user_id": "user1"},
    ).json()

    assert personalized["personal_factor"] is not None
    assert personalized["personal_factor"] > 1.0
    assert personalized["half_life_days"] > baseline


def test_personalization_is_per_user(client):
    for i in range(6):
        _log_event(client, "user1", card_id=f"c{i}")

    other_user = client.post(
        "/predict_interval",
        json={"history_seen": 3, "history_correct": 3, "user_id": "user2"},
    ).json()
    assert other_user["personal_factor"] is None
