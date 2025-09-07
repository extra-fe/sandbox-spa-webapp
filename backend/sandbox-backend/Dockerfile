FROM node:23-alpine AS builder

# 作業ディレクトリを作成
WORKDIR /usr/src/app

# package.jsonとyarn.lockをコピー
COPY package.json yarn.lock ./

# 依存関係をインストール
RUN yarn install

# アプリケーションのソースコードをコピー
COPY . .

# ビルドステップ（TypeScriptのコンパイル）
RUN yarn build

# 実行ステージ
FROM node:23-alpine

# 非特権ユーザを作成
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# 作業ディレクトリを作成
WORKDIR /usr/src/app

# 依存関係だけをコピーしてインストール
COPY package.json yarn.lock ./
RUN yarn install --production

# ビルドされたファイルとPrismaクライアントをコピー
COPY --from=builder /usr/src/app/dist ./dist

# ファイルの所有者を非特権ユーザに変更
RUN chown -R appuser:appgroup /usr/src/app

# アプリケーションの実行ポートを設定
EXPOSE 3000

# 環境変数を設定
ENV NODE_ENV=production

# 非特権ユーザでコンテナを実行
USER appuser

# アプリケーションを起動
CMD ["node", "dist/main"]
