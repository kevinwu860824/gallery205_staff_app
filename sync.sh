#!/bin/bash

# 當前專案路徑
PROJECT_DIR="/Users/j.c.wu/development/gallery205_staff_app"
cd "$PROJECT_DIR" || exit

echo "🚀 開始同步資料到 GitHub (Staff App)..."

# 1. 檢查是否已經初始化過 git
if [ ! -d ".git" ]; then
    echo "⚠️ 偵測到尚未初始化 Git，正在自動初始化..."
    git init
    # 預設添加當前目錄所有檔案
    git add .
    git commit -m "Initial commit from Auto Sync Script"
    echo "✅ Git 初始化完成。"
    echo "💡 請記得使用 'git remote add origin <你的GitHub網址>' 來關聯遠端倉庫！"
else
    # 2. 將所有修改過的檔案加入暫存區
    git add .

    # 3. 建立提交紀錄，自動帶入當前日期與時間
    git commit -m "Auto Update: $(date +'%Y-%m-%d %H:%M:%S')"

    # 4. 推送到雲端 (預設假設分支為 main)
    # 如果還沒有設定 origin，這步會失敗並提示用戶
    if git remote | grep -q "origin"; then
        CURRENT_BRANCH=$(git branch --show-current)
        git push origin "$CURRENT_BRANCH"
        echo "---------------------------------------"
        echo "✅ 同步完成！"
    else
        echo "---------------------------------------"
        echo "❌ 尚未設定遠端倉庫 (origin)，無法推送。"
        echo "請執行: git remote add origin <你的GitHub網址>"
    fi
fi
