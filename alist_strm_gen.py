#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""
AList generate STRM file (force rewrite + URL encode + full sync delete)
"""

import os
import re
import json
import requests
from urllib.parse import quote
from quark_auto_save import sort_file_by_name


class Alist_strm_gen:

    video_exts = ["mp4", "mkv", "flv", "mov", "m4v", "avi", "webm", "wmv"]
    default_config = {
        "url": "",
        "token": "",
        "storage_id": "",
        "strm_save_dir": "/media",
        "strm_replace_host": "",
        # strm_encoding 是可选的，不强制要求在配置文件里写
    }
    default_task_config = {
        "auto_gen": True,
    }
    is_active = False
    storage_mount_path = None
    quark_root_dir = None
    strm_server = None
    generated_files = []
    expected_strm_files = set()
    strm_encoding = "utf-8"  # 默认值

    def __init__(self, **kwargs):
        self.plugin_name = self.__class__.__name__.lower()

        # 只强制检查原来的必要配置
        required_keys = ["url", "token", "storage_id", "strm_save_dir"]
        missing_configs = []
        for key in required_keys:
            if key in kwargs:
                setattr(self, key, kwargs[key])
            else:
                missing_configs.append(key)

        # 可选配置
        if "strm_replace_host" in kwargs:
            self.strm_replace_host = kwargs["strm_replace_host"]
        else:
            self.strm_replace_host = ""

        if "strm_encoding" in kwargs:
            self.strm_encoding = kwargs["strm_encoding"]

        if missing_configs:
            print(f"[{self.plugin_name}] missing config: {missing_configs}")
            return

        if self.url:
            self.url = self.url.strip()
            if not self.url.startswith(("http://", "https://")):
                self.url = f"http://{self.url}"
            self.url = self.url.rstrip("/")

        if not self.url or not self.token or not self.storage_id:
            print(f"[{self.plugin_name}] config incomplete")
            return

        if not os.path.exists(self.strm_save_dir):
            try:
                os.makedirs(self.strm_save_dir)
            except Exception as e:
                print(f"[{self.plugin_name}] Create STRM dir failed: {e}")
                return

        success, result = self.storage_id_to_path(self.storage_id)
        if success:
            self.is_active = True
            self.storage_mount_path, self.quark_root_dir = result
            self.strm_replace_host = (self.strm_replace_host or "").strip().rstrip("/")
            if self.strm_replace_host:
                if self.strm_replace_host.startswith("http"):
                    self.strm_server = f"{self.strm_replace_host}/d"
                else:
                    self.strm_server = f"http://{self.strm_replace_host}/d"
            else:
                self.strm_server = f"{self.url}/d"
            print(f"[{self.plugin_name}] active OK, mount={self.storage_mount_path}, root={self.quark_root_dir}")
        else:
            print(f"[{self.plugin_name}] storage_id_to_path failed")

    def run(self, task, **kwargs):
        print(f"[{self.plugin_name}] run called, task={task.get('taskname')}")
        if not self.is_active:
            print(f"[{self.plugin_name}] not active, skip")
            return

        task_config = task.get("addition", {}).get(
            self.plugin_name, self.default_task_config
        )
        print(f"[{self.plugin_name}] task_config={task_config}")

        if not task_config.get("auto_gen"):
            print(f"[{self.plugin_name}] auto_gen=False, skip")
            return

        if not task.get("savepath"):
            print(f"[{self.plugin_name}] no savepath, skip")
            return

        savepath = os.path.normpath(task["savepath"]).replace("\\", "/")
        quark_root = os.path.normpath(self.quark_root_dir).replace("\\", "/")

        if not savepath.startswith("/"):
            savepath = "/" + savepath
        if not quark_root.startswith("/"):
            quark_root = "/" + quark_root

        print(f"[{self.plugin_name}] savepath={savepath}, quark_root={quark_root}")

        if not savepath.startswith(quark_root):
            print(f"[{self.plugin_name}] savepath not in quark root, skip")
            return

        alist_path = os.path.normpath(
            os.path.join(
                self.storage_mount_path,
                savepath.replace(quark_root, "", 1).lstrip("/"),
            )
        ).replace("\\", "/")

        print(f"[{self.plugin_name}] alist_path={alist_path}")

        self.generated_files = []
        self.expected_strm_files = set()

        self.check_dir(alist_path)
        self.cleanup_orphan_strm(alist_path)

        if self.generated_files:
            sorted_files = sorted(self.generated_files, key=sort_file_by_name)
            for file_path in sorted_files:
                print(f"Generate STRM: {file_path} OK")
        else:
            print(f"[{self.plugin_name}] no strm generated")

    def storage_id_to_path(self, storage_id):
        storage_mount_path, quark_root_dir = None, None

        if match := re.match(r"^(\/[^:]*):(\/[^:]*)$", storage_id):
            storage_mount_path, quark_root_dir = match.group(1), match.group(2)
            file_list = self.get_file_list(storage_mount_path)
            if file_list.get("code") != 200:
                print(f"AList-Strm: get mount path failed: {file_list.get('message')}")
                return False, (None, None)

        elif re.match(r"^\d+$", storage_id):
            if storage_info := self.get_storage_info(storage_id):
                if storage_info["driver"] == "Quark":
                    addition = json.loads(storage_info["addition"])
                    storage_mount_path = storage_info["mount_path"]
                    quark_root_dir = self.get_root_folder_full_path(
                        addition["cookie"], addition["root_folder_id"]
                    )
                elif storage_info["driver"] == "QuarkTV":
                    print("AList-Strm: QuarkTV driver, please use /mount:/quarkpath")
                else:
                    print(f"AList-Strm: unsupported driver [{storage_info['driver']}]")
        else:
            print(f"AList-Strm: storage_id [{storage_id}] format error")

        if storage_mount_path and quark_root_dir:
            print(f"AList-Strm: [{storage_mount_path}:{quark_root_dir}]")
            return True, (storage_mount_path, quark_root_dir)
        else:
            return False, (None, None)

    def get_storage_info(self, storage_id):
        url = f"{self.url}/api/admin/storage/get"
        headers = {"Authorization": self.token}
        querystring = {"id": storage_id}
        try:
            response = requests.request("GET", url, headers=headers, params=querystring)
            response.raise_for_status()
            data = response.json()
            if data.get("code") == 200:
                return data.get("data", [])
            else:
                print(f"AList-Strm: get storage failed: {data.get('message')}")
        except Exception as e:
            print(f"AList-Strm: get storage error: {e}")
        return []

    def check_dir(self, path):
        data = self.get_file_list(path)
        if data.get("code") != 200:
            print(f"AList-Strm: list failed: {data.get('message')}")
            return
        elif files := data.get("data", {}).get("content"):
            for item in files:
                item_path = f"{path}/{item.get('name')}".replace("//", "/")
                if item.get("is_dir"):
                    self.check_dir(item_path)
                else:
                    self.generate_strm(item_path)

    def get_file_list(self, path, force_refresh=False):
        url = f"{self.url}/api/fs/list"
        headers = {"Authorization": self.token}
        payload = {
            "path": path,
            "refresh": force_refresh,
            "password": "",
            "page": 1,
            "per_page": 0,
        }
        try:
            response = requests.request("POST", url, headers=headers, json=payload)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"AList-Strm: list error: {e}")
        return {}

    def generate_strm(self, file_path):
        ext = file_path.split(".")[-1]
        if ext.lower() not in self.video_exts:
            return

        strm_path = (
            f"{self.strm_save_dir}{os.path.splitext(file_path)[0]}.strm".replace("//", "/")
        )
        self.expected_strm_files.add(os.path.normpath(strm_path))

        # URL encode path (keep /)
        encoded_path = quote(file_path, safe="/")
        content = f"{self.strm_server}{encoded_path}"

        # 强制总是重写
        if not os.path.exists(os.path.dirname(strm_path)):
            try:
                os.makedirs(os.path.dirname(strm_path))
            except Exception as e:
                print(f"Create dir failed: {os.path.dirname(strm_path)} {e}")
                return

        try:
            with open(strm_path, "w", encoding=self.strm_encoding) as strm_file:
                strm_file.write(content)
            self.generated_files.append(strm_path)
        except Exception as e:
            print(f"Generate STRM failed: {strm_path} {e}")

    def cleanup_orphan_strm(self, alist_path):
        """Delete local strm files that no longer exist on cloud"""
        local_root = os.path.normpath(
            f"{self.strm_save_dir}{alist_path}".replace("//", "/")
        )

        if not os.path.exists(local_root):
            return

        deleted = []
        for root, dirs, files in os.walk(local_root):
            for name in files:
                if not name.lower().endswith(".strm"):
                    continue
                local_file = os.path.normpath(os.path.join(root, name))
                if local_file not in self.expected_strm_files:
                    try:
                        os.remove(local_file)
                        deleted.append(local_file)
                    except Exception as e:
                        print(f"Delete orphan STRM failed: {local_file} {e}")

        for root, dirs, files in os.walk(local_root, topdown=False):
            for d in dirs:
                dir_path = os.path.join(root, d)
                try:
                    if not os.listdir(dir_path):
                        os.rmdir(dir_path)
                except Exception:
                    pass

        if deleted:
            for f in sorted(deleted, key=sort_file_by_name):
                print(f"Deleted orphan STRM: {f}")

    def get_root_folder_full_path(self, cookie, pdir_fid):
        if pdir_fid == "0":
            return "/"
        url = "https://drive-h.quark.cn/1/clouddrive/file/sort"
        headers = {
            "cookie": cookie,
            "content-type": "application/json",
        }
        querystring = {
            "pr": "ucpro",
            "fr": "pc",
            "uc_param_str": "",
            "pdir_fid": pdir_fid,
            "_page": 1,
            "_size": "50",
            "_fetch_total": "1",
            "_fetch_sub_dirs": "0",
            "_sort": "file_type:asc,updated_at:desc",
            "_fetch_full_path": 1,
        }
        try:
            response = requests.request(
                "GET", url, headers=headers, params=querystring
            ).json()
            if response["code"] == 0:
                path = ""
                for item in response["data"]["full_path"]:
                    path = f"{path}/{item['file_name']}"
                return path
        except Exception as e:
            print(f"AList-Strm: get Quark path error: {e}")
        return ""
