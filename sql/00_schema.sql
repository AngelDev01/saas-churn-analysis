-- Recreate the schema
CREATE SCHEMA churn_analysis;

-- create all tables
CREATE TABLE churn_analysis.accounts (
    account_id INTEGER PRIMARY KEY,
    signup_date DATE NOT NULL,
    acquisition_channel VARCHAR(50) NOT NULL,
    company_size VARCHAR(50) NOT NULL,
    original_plan VARCHAR(50) NOT NULL,
    cac NUMERIC(10,2) NOT NULL,
    region VARCHAR(10) NOT NULL,
    
    CONSTRAINT valid_channel CHECK (acquisition_channel IN ('organic', 'paid_social', 'referral', 'content')),
    CONSTRAINT valid_size CHECK (company_size IN ('solo', 'small', 'mid', 'enterprise')),
    CONSTRAINT valid_plan CHECK (original_plan IN ('basic', 'pro', 'team')),
    CONSTRAINT valid_region CHECK (region IN ('US', 'EU', 'APAC'))
);

CREATE TABLE churn_analysis.subscriptions (
    subscription_id INTEGER PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES churn_analysis.accounts(account_id),
    start_date DATE NOT NULL,
    end_date DATE,
    plan VARCHAR(50) NOT NULL,
    mrr NUMERIC(10,2) NOT NULL,
    billing_period VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    
    CONSTRAINT valid_sub_plan CHECK (plan IN ('basic', 'pro', 'team')),
    CONSTRAINT valid_billing CHECK (billing_period IN ('monthly', 'annual')),
    CONSTRAINT valid_status CHECK (status IN ('active', 'cancelled', 'upgraded', 'downgraded')),
    CONSTRAINT valid_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TABLE churn_analysis.events (
    event_id INTEGER PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES churn_analysis.accounts(account_id),
    event_timestamp TIMESTAMP,
    event_type VARCHAR(50) NOT NULL,
    session_duration_sec INTEGER,
    
    CONSTRAINT valid_event_type CHECK (event_type IN (
        'login', 'feature_report_run', 'feature_export', 
        'feature_team_invite', 'support_ticket'
    )),
    CONSTRAINT valid_duration CHECK (session_duration_sec IS NULL OR session_duration_sec >= 0)
);

CREATE TABLE churn_analysis.invoices (
    invoice_id INTEGER PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES churn_analysis.accounts(account_id),
    invoice_date DATE NOT NULL,
    gross_amount NUMERIC(10,2) NOT NULL,
    discount_pct NUMERIC(4,2) NOT NULL DEFAULT 0,
    net_revenue NUMERIC(10,2) NOT NULL,
    status VARCHAR(50) NOT NULL,
    billing_period VARCHAR(50) NOT NULL,
    
    CONSTRAINT valid_inv_status CHECK (status IN ('paid', 'failed', 'past_due', 'written_off', 'refunded')),
    CONSTRAINT valid_inv_billing CHECK (billing_period IN ('monthly', 'annual')),
    CONSTRAINT valid_discount CHECK (discount_pct >= 0 AND discount_pct <= 1)
);

-- Indexes
CREATE INDEX idx_subscriptions_account ON churn_analysis.subscriptions(account_id);
CREATE INDEX idx_subscriptions_dates ON churn_analysis.subscriptions(start_date, end_date);
CREATE INDEX idx_events_account ON churn_analysis.events(account_id);
CREATE INDEX idx_events_timestamp ON churn_analysis.events(event_timestamp);
CREATE INDEX idx_events_type ON churn_analysis.events(event_type);
CREATE INDEX idx_invoices_account ON churn_analysis.invoices(account_id);
CREATE INDEX idx_invoices_date ON churn_analysis.invoices(invoice_date);

-- Supporting tables
CREATE TABLE churn_analysis.metric (
    account_id INTEGER NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    metric_time TIMESTAMP NOT NULL,
    metric_value FLOAT,
    user_id INTEGER,
    PRIMARY KEY (account_id, metric_name, metric_time)
);

CREATE TABLE churn_analysis.active_period (
    account_id INT NOT NULL,
    start_date DATE NOT NULL,
    churn_date DATE,
    PRIMARY KEY (account_id, start_date)
);

CREATE TABLE churn_analysis.observation_dates (
    account_id INT NOT NULL,
    observation_date DATE NOT NULL,
    is_churn BOOLEAN NOT NULL,
    PRIMARY KEY (account_id, observation_date)
);
