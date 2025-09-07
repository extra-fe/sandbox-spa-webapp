import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { Logger, LogLevel } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const logLevel = (process.env.LOG_LEVEL ?? 'error') as LogLevel;
  Logger.overrideLogger([logLevel]);

  if (process.env.CORS_ORIGIN && process.env.CORS_METHODS) {
    app.enableCors({
      origin: process.env.CORS_ORIGIN.split(','),
      methods: process.env.CORS_METHODS.split(','),
      credentials: true,
    });
  }

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
