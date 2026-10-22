def test_predict_interval_basic_shape(client):
    response = client.post(
        "/predict_interval",
        json={"history_seen": 3, "history_correct": 3},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["half_life_days"] > 0
    assert body["next_interval_days"] > 0
    assert body["recall_probability"] is None
    assert body["personal_factor"] is None


def test_recall_probability_only_when_delta_given(client):
    with_delta = client.post(
        "/predict_interval",
        json={"history_seen": 3, "history_correct": 3, "delta": 86400},
    ).json()
    assert with_delta["recall_probability"] is not None
    assert 0 < with_delta["recall_probability"] < 1

    without_delta = client.post(
        "/predict_interval",
        json={"history_seen": 3, "history_correct": 3},
    ).json()
    assert without_delta["recall_probability"] is None


def test_more_correct_history_means_longer_half_life(client):
    """Sanity check against the fixture model's own fitted relationship,
    not a hardcoded Duolingo-model expectation."""
    mostly_right = client.post(
        "/predict_interval",
        json={"history_seen": 10, "history_correct": 9},
    ).json()
    mostly_wrong = client.post(
        "/predict_interval",
        json={"history_seen": 10, "history_correct": 1},
    ).json()
    assert mostly_right["half_life_days"] > mostly_wrong["half_life_days"]


def test_target_recall_changes_next_interval(client):
    conservative = client.post(
        "/predict_interval",
        json={"history_seen": 5, "history_correct": 5, "target_recall": 0.95},
    ).json()
    lenient = client.post(
        "/predict_interval",
        json={"history_seen": 5, "history_correct": 5, "target_recall": 0.7},
    ).json()
    # Asking to still remember with higher probability means a shorter interval.
    assert conservative["next_interval_days"] < lenient["next_interval_days"]
