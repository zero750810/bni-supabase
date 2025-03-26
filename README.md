# BNI Supabase 資料庫設置

這個專案包含了 BNI 分會活動管理系統的 Supabase 資料庫設置腳本。

## 如何使用

1. 在 [Supabase](https://supabase.com) 創建新專案
2. 進入專案的 SQL 編輯器
3. 複製 `supabase/migrations/0001_initial_schema.sql` 的內容
4. 在 SQL 編輯器中執行該腳本

## 資料表結構

### 分會表 (branches)
- id: UUID (主鍵)
- name: TEXT
- created_at: TIMESTAMP

### 會員表 (members)
- id: UUID (主鍵)
- branch_id: UUID (外鍵 -> branches.id)
- name: TEXT
- qr_code: TEXT
- photo_url: TEXT
- created_at: TIMESTAMP

### 活動表 (events)
- id: UUID (主鍵)
- branch_id: UUID (外鍵 -> branches.id)
- date: DATE
- title: TEXT
- participants: UUID[]
- created_at: TIMESTAMP

### 報到表 (attendance)
- id: UUID (主鍵)
- event_id: UUID (外鍵 -> events.id)
- member_id: UUID (外鍵 -> members.id)
- check_in_time: TIMESTAMP
- created_at: TIMESTAMP

### 簡報順序表 (presentation_orders)
- id: UUID (主鍵)
- event_id: UUID (外鍵 -> events.id)
- branch_id: UUID (外鍵 -> branches.id)
- member_id: UUID (外鍵 -> members.id)
- order: INTEGER
- created_at: TIMESTAMP

### 用戶表 (users)
- id: UUID (主鍵，關聯到 auth.users)
- email: TEXT
- role: user_role
- branch_id: UUID (外鍵 -> branches.id)
- created_at: TIMESTAMP

## 權限設置

系統定義了四種用戶角色：
- 管理員 (admin)：完全訪問權限
- 分會管理人員 (branch_manager)：可以管理自己分會的所有資料
- 簡報控制人員 (presentation_controller)：可以讀取自己分會的資料和控制簡報
- 匿名用戶 (anonymous)：只能進行報到操作

每個資料表都啟用了行級安全性 (RLS)，並根據用戶角色設置了相應的訪問策略。