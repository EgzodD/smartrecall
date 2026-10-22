def _card(card_id="card1", **overrides):
    base = {
        "id": card_id,
        "lexeme_id": "wasser",
        "learning_language": "de",
        "front": "das Wasser",
        "back": "the water",
        "history_seen": 1,
        "history_correct": 1,
        "last_reviewed_at": "2026-09-10T10:00:00",
        "due_at": "2026-09-12T10:00:00",
        "updated_at": "2026-09-10T10:00:00",
    }
    base.update(overrides)
    return base


def test_push_then_pull_on_another_device(client):
    push = client.post("/sync/user1", json={"cards": [_card()]})
    assert push.status_code == 200
    assert push.json()["cards"] == [_card()]

    # A second device with nothing local should receive the pushed card back.
    pull = client.post("/sync/user1", json={"cards": []})
    assert pull.json()["cards"] == [_card()]


def test_newer_update_overwrites_older(client):
    client.post("/sync/user1", json={"cards": [_card()]})
    updated = _card(
        history_seen=2,
        history_correct=2,
        last_reviewed_at="2026-09-10T12:00:00",
        due_at="2026-09-20T12:00:00",
        updated_at="2026-09-10T12:00:00",
    )
    response = client.post("/sync/user1", json={"cards": [updated]})
    assert response.json()["cards"] == [updated]


def test_stale_update_is_rejected(client):
    newer = _card(
        history_seen=2,
        history_correct=2,
        updated_at="2026-09-10T12:00:00",
    )
    client.post("/sync/user1", json={"cards": [_card()]})
    client.post("/sync/user1", json={"cards": [newer]})

    stale = _card(history_seen=1, history_correct=1, updated_at="2026-09-10T10:00:00")
    response = client.post("/sync/user1", json={"cards": [stale]})

    assert response.json()["cards"][0]["history_seen"] == 2


def test_users_are_isolated(client):
    client.post("/sync/user1", json={"cards": [_card()]})
    response = client.post("/sync/user2", json={"cards": []})
    assert response.json()["cards"] == []
