-- ========================
-- EXTENSIONS
-- ========================
CREATE EXTENSION IF NOT EXISTS vector;

-- ========================
-- 1. BRANDS
-- ========================
CREATE TABLE brands (
    brand_id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    country VARCHAR(100)
);

-- ========================
-- 2. CATEGORIES
-- ========================
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

-- ========================
-- 3. ACCOUNTS
-- ========================
CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    email_confirm BOOLEAN DEFAULT FALSE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'customer' CHECK (role IN ('customer','staff','admin')),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','locked','disabled','pending')),
    -- 2FA
    is_2fa_enabled BOOLEAN DEFAULT FALSE,
    twofa_secret VARCHAR(255),
    twofa_recovery_codes TEXT,
    -- security
    failed_login_attempts INT DEFAULT 0,
    last_failed_login TIMESTAMP,
    created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modified_on TIMESTAMP
);

-- ========================
-- 4. PRODUCTS
-- ========================
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    brand_id INT,
    category_id INT,
    status VARCHAR(20) DEFAULT 'active',
    FOREIGN KEY (brand_id) REFERENCES brands(brand_id),
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

-- ========================
-- 5. PRODUCT ITEMS
-- ========================
CREATE TABLE product_items (
    product_item_id SERIAL PRIMARY KEY,
    product_id INT NOT NULL,
    sku VARCHAR(100) UNIQUE,
    specifications JSONB,
    price NUMERIC(12,2) NOT NULL,
    sale_price NUMERIC(12,2),
    stock_quantity INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active',
    description TEXT,
    images JSONB,
    main_image_url TEXT,
    embedding vector(1536),
    embedding_text TEXT,
    created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);
CREATE INDEX idx_product_embedding ON product_items USING ivfflat (embedding vector_cosine_ops);
CREATE INDEX idx_product_items_product ON product_items(product_id);

-- ========================
-- 6. SERIAL NUMBERS
-- ========================
CREATE TABLE serial_numbers (
    serial_id SERIAL PRIMARY KEY,
    product_item_id INT NOT NULL,
    serial_code VARCHAR(255) UNIQUE NOT NULL,
    status VARCHAR(20) DEFAULT 'in_stock' CHECK (status IN ('in_stock','sold','warranty','returned')),
    import_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_item_id) REFERENCES product_items(product_item_id)
);
CREATE INDEX idx_serial_status ON serial_numbers(status);

-- ========================
-- 7. PROFILES
-- ========================
CREATE TABLE profiles (
    profile_id SERIAL PRIMARY KEY,
    account_id INT UNIQUE NOT NULL,
    full_name VARCHAR(255),
    phone VARCHAR(20),
    address TEXT,
    avatar_url TEXT,
    created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE CASCADE
);

-- ========================
-- 8. USER SESSIONS
-- ========================
CREATE TABLE user_sessions (
    session_id SERIAL PRIMARY KEY,
    account_id INT NOT NULL,
    refresh_token TEXT NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE CASCADE
);

-- ========================
-- 9. CARTS
-- ========================
CREATE TABLE carts (
    cart_id SERIAL PRIMARY KEY,
    account_id INT NOT NULL,
    created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_on TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE CASCADE
);
CREATE INDEX idx_cart_account ON carts(account_id);

-- ========================
-- 10. CART ITEMS
-- ========================
CREATE TABLE cart_items (
    cart_item_id SERIAL PRIMARY KEY,
    cart_id INT NOT NULL,
    product_item_id INT NOT NULL,
    quantity INT DEFAULT 1 CHECK (quantity > 0),
    FOREIGN KEY (cart_id) REFERENCES carts(cart_id) ON DELETE CASCADE,
    FOREIGN KEY (product_item_id) REFERENCES product_items(product_item_id)
);

-- ========================
-- 11. ORDERS
-- ========================
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    account_id INT NOT NULL,
    order_code VARCHAR(50) UNIQUE,
    total_price NUMERIC(12,2),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending','shipping','completed','cancelled')),
    payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending','paid','failed','refunded')),
    payment_method VARCHAR(50),
    shipping_address TEXT,
    phone VARCHAR(20),
    created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);
CREATE INDEX idx_orders_account ON orders(account_id);
CREATE INDEX idx_orders_status ON orders(status);

-- ========================
-- 12. ORDER ITEMS
-- ========================
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    product_item_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    price NUMERIC(12,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_item_id) REFERENCES product_items(product_item_id)
);
CREATE INDEX idx_order_items_order ON order_items(order_id);

-- ========================
-- 13. PAYMENTS
-- ========================
CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    amount NUMERIC(12,2),
    method VARCHAR(50),
    status VARCHAR(20) CHECK (status IN ('pending','success','failed')),
    transaction_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

-- ========================
-- 14. SOLD SERIALS
-- ========================
CREATE TABLE sold_serials (
    sold_serial_id SERIAL PRIMARY KEY,
    order_item_id INT NOT NULL,
    serial_id INT NOT NULL,
    FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id),
    FOREIGN KEY (serial_id) REFERENCES serial_numbers(serial_id)
);

-- ========================
-- 15. WARRANTIES
-- ========================
CREATE TABLE warranties (
    warranty_id SERIAL PRIMARY KEY,
    serial_id INT UNIQUE NOT NULL,
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) CHECK (status IN ('active','claimed','expired')),
    FOREIGN KEY (serial_id) REFERENCES serial_numbers(serial_id)
);

-- ========================
-- 16. WARRANTY CLAIMS
-- ========================
CREATE TABLE warranty_claims (
    claim_id SERIAL PRIMARY KEY,
    serial_id INT NOT NULL,
    account_id INT NOT NULL,
    issue_description TEXT,
    status VARCHAR(20) CHECK (status IN ('pending','approved','rejected','completed')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (serial_id) REFERENCES serial_numbers(serial_id),
    FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

-- ========================
-- 17. PROMOTIONS
-- ========================
CREATE TABLE promotions (
    promotion_id SERIAL PRIMARY KEY,
    promotion_name VARCHAR(150),
    discount_percent NUMERIC(5,2),
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- ========================
-- 18. PRODUCT PROMOTIONS
-- ========================
CREATE TABLE product_promotions (
    product_id INT,
    promotion_id INT,
    PRIMARY KEY (product_id, promotion_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (promotion_id) REFERENCES promotions(promotion_id) ON DELETE CASCADE
);

-- ========================
-- 19. NOTIFICATIONS
-- ========================
CREATE TABLE notifications (
    notification_id SERIAL PRIMARY KEY,
    account_id INT NOT NULL,
    title VARCHAR(255),
    message TEXT,
    type VARCHAR(50) CHECK (type IN ('order','promotion','system','warning')),
    is_read BOOLEAN DEFAULT FALSE,
    created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE CASCADE
);
CREATE INDEX idx_notifications_account ON notifications(account_id);
CREATE INDEX idx_notifications_read ON notifications(is_read);

-- ========================
-- 20. AUDIT LOGS
-- ========================
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    account_id INT,
    action VARCHAR(255),
    entity VARCHAR(100),
    entity_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

-- ========================
-- 21. BANK TRANSACTIONS
-- ========================
CREATE TABLE bank_transactions (
    transaction_id BIGSERIAL PRIMARY KEY,
    gateway VARCHAR(100) NOT NULL,
    transaction_date TIMESTAMP NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    code VARCHAR(255),
    content TEXT,
    transfer_type VARCHAR(10) NOT NULL,
    transfer_amount NUMERIC(18,2) NOT NULL,
    accumulated NUMERIC(18,2) NOT NULL,
    subaccount VARCHAR(50),
    reference_code VARCHAR(255),
    description TEXT,
    created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modified_on TIMESTAMP
);
CREATE INDEX idx_bank_date ON bank_transactions(transaction_date);