"""The eight taxonomy Patterns seeded into the graph (see GLOSSARY.md: Pattern).

Seven scam archetypes plus one legit bucket, so Guard can judge a message
that matches no scam honestly as legitimate.
"""

glob PATTERN_TAXONOMY: list[dict[str, str]] = [
    {
        "name": "wrong_number_reversal",
        "title": "Wrong-number reversal",
        "description": "Claims money was sent to you by mistake and asks you to send it back."
    },
    {
        "name": "fee_before_loan",
        "title": "Fee before loan",
        "description": "Promises a loan once you pay a processing, insurance or activation fee first."
    },
    {
        "name": "fake_prize_promo",
        "title": "Fake prize or promotion",
        "description": "Says you won a prize or promotion and must pay or share details to claim it."
    },
    {
        "name": "fake_confirmation",
        "title": "Fake payment confirmation",
        "description": "Imitates a mobile-money confirmation for a payment that never happened."
    },
    {
        "name": "impersonation",
        "title": "Impersonation",
        "description": "Pretends to be a telco, bank, agent, official or relative to get money or details."
    },
    {
        "name": "fake_job_or_visa_fee",
        "title": "Fake job or visa fee",
        "description": "Offers a job, visa or travel opportunity that requires an upfront fee."
    },
    {
        "name": "sim_swap_otp_request",
        "title": "SIM swap or OTP request",
        "description": "Asks for a PIN, OTP or code, or prepares a SIM swap to take over the account."
    },
    {
        "name": "legit_transaction",
        "title": "Legitimate transaction or notice",
        "description": "A genuine transaction confirmation or service notice that asks for nothing risky."
    }
];
