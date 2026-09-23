FROM node:22

WORKDIR /usr/src/app

COPY package.json package-lock.json ./
RUN npm install

COPY . .

EXPOSE 8787

CMD ["npm", "run", "dev"]
