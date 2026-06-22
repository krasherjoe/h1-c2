#!/usr/bin/env python3
"""
Agent-Mattermost Bridge
ICE-APIが利用できない場合にMattermost経由で通信するブリッジスクリプト
"""

import requests
import json
import time
import sys
from typing import Optional

class MattermostBridge:
    def __init__(self, base_url: str, pat: str, channel_id: str):
        self.base_url = base_url.rstrip('/')
        self.pat = pat
        self.channel_id = channel_id
        self.headers = {
            'Authorization': f'Bearer {pat}',
            'Content-Type': 'application/json'
        }
        self.last_message_time = None

    def send_command(self, command: str, args: list = None) -> str:
        """コマンドをMattermostに送信し、応答を待つ"""
        if args is None:
            args = []
        
        message = f"!opencode {command} {' '.join(args)}"
        return self._send_and_wait(message)

    def _send_and_wait(self, message: str, timeout: int = 300) -> str:
        """メッセージを送信し、応答を待つ"""
        # メッセージ送信
        url = f"{self.base_url}/api/v4/posts"
        payload = {
            'channel_id': self.channel_id,
            'message': message
        }
        
        response = requests.post(url, headers=self.headers, json=payload)
        if response.status_code != 201:
            raise Exception(f"Failed to send message: {response.status_code}")
        
        post_data = response.json()
        post_id = post_data['id']
        
        # 応答を待つ
        start_time = time.time()
        while time.time() - start_time < timeout:
            time.sleep(2)  # 2秒間隔でチェック
            
            # 新しいメッセージを取得
            messages = self._get_messages()
            if messages is None:
                continue
            
            # 自分のメッセージへのリプライを探す
            for msg in messages:
                if msg.get('root_id') == post_id:
                    return msg.get('message', '')
        
        raise Exception("Timeout waiting for response")

    def _get_messages(self):
        """新しいメッセージを取得"""
        url = f"{self.base_url}/api/v4/channels/{self.channel_id}/posts"
        response = requests.get(url, headers=self.headers)
        
        if response.status_code != 200:
            return None
        
        data = response.json()
        posts = data['posts']
        order = data['order']
        
        messages = [posts[pid] for pid in order]
        
        if self.last_message_time:
            messages = [m for m in messages if m['create_at'] > self.last_message_time]
        
        if messages:
            self.last_message_time = max(m['create_at'] for m in messages)
        
        return messages

    @staticmethod
    def extract_channel_id_from_url(url: str, pat: str) -> Optional[str]:
        """URLからチャンネルIDを抽出"""
        # URL形式: https://mm.ka.sugeee.com/cyb/channels/h1-debug
        # チャンネル名を抽出
        import re
        match = re.search(r'/channels/([^/]+)$', url)
        if not match:
            return None
        
        channel_name = match.group(1)
        base_url = url.split('/cyb/')[0]  # ベースURLを抽出
        
        # チャンネル名からIDを取得
        headers = {'Authorization': f'Bearer {pat}'}
        
        # チームIDを取得
        teams_url = f"{base_url}/api/v4/users/me/teams"
        response = requests.get(teams_url, headers=headers)
        if response.status_code != 200:
            return None
        
        teams = response.json()
        if not teams:
            return None
        
        team_id = teams[0]['id']
        
        # チャンネルIDを取得
        channels_url = f"{base_url}/api/v4/teams/{team_id}/channels/name/{channel_name}"
        response = requests.get(channels_url, headers=headers)
        if response.status_code != 200:
            return None
        
        channel_data = response.json()
        return channel_data.get('id')

def try_ice_api(ice_url: str, command: str, args: list = None) -> Optional[str]:
    """ICE-APIを試す"""
    if args is None:
        args = []
    
    try:
        url = f"{ice_url}/command"
        payload = {
            'command': command,
            'args': args
        }
        
        response = requests.post(url, json=payload, timeout=5)
        if response.status_code == 200:
            data = response.json()
            return data.get('result')
    except Exception as e:
        print(f"ICE-API failed: {e}", file=sys.stderr)
    
    return None

def main():
    import os
    import re
    
    # 環境変数から設定を取得（既存の変数名をサポート）
    ice_url = os.environ.get('ICE_API_URL', 'http://localhost:8080')
    
    # 既存の環境変数名をサポート
    mm_base_url = os.environ.get('MATTERMOST_BASE_URL') or os.environ.get('MM_H1DB_URL')
    mm_pat = os.environ.get('MATTERMOST_PAT') or os.environ.get('MM_H1DB_TOKEN')
    mm_channel_id = os.environ.get('MATTERMOST_CHANNEL_ID')
    
    # URLからチャンネルIDを抽出
    if mm_base_url and not mm_channel_id:
        # URL形式: https://mm.ka.sugeee.com/cyb/channels/h1-debug
        # チャンネル名からIDを自動取得
        mm_channel_id = MattermostBridge.extract_channel_id_from_url(mm_base_url, mm_pat)
        if mm_channel_id:
            print(f"Extracted channel ID: {mm_channel_id}", file=sys.stderr)
        else:
            print("Warning: Could not extract channel ID from URL", file=sys.stderr)
    
    if len(sys.argv) < 2:
        print("Usage: agent_mattermost_bridge.py <command> [args...]")
        sys.exit(1)
    
    command = sys.argv[1]
    args = sys.argv[2:]
    
    # まずICE-APIを試す
    result = try_ice_api(ice_url, command, args)
    if result is not None:
        print(result)
        return
    
    # ICE-APIがダメならMattermostにフォールバック
    if not all([mm_base_url, mm_pat]):
        print("Error: ICE-API failed and Mattermost not configured", file=sys.stderr)
        print("Required: MM_H1DB_URL and MM_H1DB_TOKEN (or MATTERMOST_BASE_URL and MATTERMOST_PAT)", file=sys.stderr)
        sys.exit(1)
    
    print("ICE-API unavailable, using Mattermost fallback...", file=sys.stderr)
    
    # チャンネルIDがURLから取得できない場合はエラー
    if not mm_channel_id:
        print("Error: MATTERMOST_CHANNEL_ID or channel ID extraction required", file=sys.stderr)
        print("Current URL format requires separate channel ID", file=sys.stderr)
        sys.exit(1)
    
    bridge = MattermostBridge(mm_base_url, mm_pat, mm_channel_id)
    try:
        result = bridge.send_command(command, args)
        print(result)
    except Exception as e:
        print(f"Mattermost fallback failed: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
