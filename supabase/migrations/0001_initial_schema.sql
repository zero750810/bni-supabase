-- 創建自定義類型
CREATE TYPE user_role AS ENUM ('admin', 'branch_manager', 'presentation_controller', 'anonymous');

-- 啟用必要的擴展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 創建分會表
CREATE TABLE branches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 創建會員表
CREATE TABLE members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    qr_code TEXT NOT NULL UNIQUE,
    photo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 創建活動表
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    title TEXT NOT NULL,
    participants UUID[] NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 創建報到表
CREATE TABLE attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    member_id UUID REFERENCES members(id) ON DELETE CASCADE,
    check_in_time TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE(event_id, member_id)
);

-- 創建簡報順序表
CREATE TABLE presentation_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    member_id UUID REFERENCES members(id) ON DELETE CASCADE,
    "order" INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE(event_id, member_id)
);

-- 創建用戶表
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    role user_role NOT NULL DEFAULT 'anonymous',
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 設置 RLS 策略
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE presentation_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 創建策略函數
CREATE OR REPLACE FUNCTION get_user_role() RETURNS user_role AS $$
BEGIN
    RETURN (
        SELECT role FROM users WHERE id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_branch_id() RETURNS UUID AS $$
BEGIN
    RETURN (
        SELECT branch_id FROM users WHERE id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 分會表策略
CREATE POLICY "管理員可以完全訪問分會表" ON branches
    FOR ALL USING (get_user_role() = 'admin');

CREATE POLICY "分會管理人員和簡報控制人員只能讀取自己的分會" ON branches
    FOR SELECT USING (
        get_user_role() IN ('branch_manager', 'presentation_controller')
        AND id = get_user_branch_id()
    );

-- 會員表策略
CREATE POLICY "管理員可以完全訪問會員表" ON members
    FOR ALL USING (get_user_role() = 'admin');

CREATE POLICY "分會管理人員可以管理自己分會的會員" ON members
    FOR ALL USING (
        get_user_role() = 'branch_manager'
        AND branch_id = get_user_branch_id()
    );

CREATE POLICY "簡報控制人員只能讀取自己分會的會員" ON members
    FOR SELECT USING (
        get_user_role() = 'presentation_controller'
        AND branch_id = get_user_branch_id()
    );

-- 活動表策略
CREATE POLICY "管理員可以完全訪問活動表" ON events
    FOR ALL USING (get_user_role() = 'admin');

CREATE POLICY "分會管理人員可以管理自己分會的活動" ON events
    FOR ALL USING (
        get_user_role() = 'branch_manager'
        AND branch_id = get_user_branch_id()
    );

CREATE POLICY "簡報控制人員只能讀取自己分會的活動" ON events
    FOR SELECT USING (
        get_user_role() = 'presentation_controller'
        AND branch_id = get_user_branch_id()
    );

-- 報到表策略
CREATE POLICY "管理員可以完全訪問報到表" ON attendance
    FOR ALL USING (get_user_role() = 'admin');

CREATE POLICY "分會管理人員可以管理自己分會的報到記錄" ON attendance
    FOR ALL USING (
        get_user_role() = 'branch_manager'
        AND event_id IN (
            SELECT id FROM events WHERE branch_id = get_user_branch_id()
        )
    );

CREATE POLICY "簡報控制人員只能讀取自己分會的報到記錄" ON attendance
    FOR SELECT USING (
        get_user_role() = 'presentation_controller'
        AND event_id IN (
            SELECT id FROM events WHERE branch_id = get_user_branch_id()
        )
    );

CREATE POLICY "匿名用戶可以新增報到記錄" ON attendance
    FOR INSERT WITH CHECK (true);

-- 簡報順序表策略
CREATE POLICY "管理員可以完全訪問簡報順序表" ON presentation_orders
    FOR ALL USING (get_user_role() = 'admin');

CREATE POLICY "分會管理人員可以管理自己分會的簡報順序" ON presentation_orders
    FOR ALL USING (
        get_user_role() = 'branch_manager'
        AND branch_id = get_user_branch_id()
    );

CREATE POLICY "簡報控制人員可以讀取和更新自己分會的簡報順序" ON presentation_orders
    FOR ALL USING (
        get_user_role() = 'presentation_controller'
        AND branch_id = get_user_branch_id()
    );

-- 用戶表策略
CREATE POLICY "管理員可以完全訪問用戶表" ON users
    FOR ALL USING (get_user_role() = 'admin');

CREATE POLICY "用戶可以讀取自己的資料" ON users
    FOR SELECT USING (auth.uid() = id);

-- 創建觸發器函數
CREATE OR REPLACE FUNCTION create_user_on_signup()
RETURNS trigger AS $$
BEGIN
    INSERT INTO users (id, email, role)
    VALUES (NEW.id, NEW.email, 'anonymous');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 創建觸發器
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION create_user_on_signup();