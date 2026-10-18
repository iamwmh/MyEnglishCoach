# 英语教练 网站

静态站点，用于介绍应用，并为 App Store 提供可公开访问的隐私政策。

## 页面

| 文件 | 用途 | App Store 对应项 |
| --- | --- | --- |
| `index.html` | 功能、特色、界面截图、使用方法 | Support URL / 营销网址 |
| `privacy.html` | 隐私政策（中英） | Privacy Policy URL |
| `404.html` | GitHub Pages 未找到页面 | — |
| `assets/img/` | App 图标与界面截图 | — |

## 用 GitHub Pages 发布

1. 把本仓库推送到 GitHub。
2. 打开仓库 **Settings → Pages**。
3. Source 选 **Deploy from a branch**。
4. Branch 选 `main`（或你的默认分支），文件夹选 **`/docs`**。
5. 保存后，网站地址一般为：

```text
https://<GitHub用户名>.github.io/<仓库名>/
https://<GitHub用户名>.github.io/<仓库名>/privacy.html
```

把第二条填进 App Store Connect 的 **Privacy Policy URL**。

若仓库名是 `MyEnglishCoach`、用户名是 `example`：

```text
https://example.github.io/MyEnglishCoach/privacy.html
```

## 上架前请核对

- 把 `privacy.html` 里的联系方式改成你在 App Store Connect 登记的邮箱。
- 若启用自定义域名，在 `docs/` 下增加 `CNAME` 文件，内容为一行域名。
- 语音识别走系统 Speech 框架：政策中已说明可能使用 Apple 服务，请勿改成「绝不离开本机」，除非你在应用里强制了 on-device recognition。
