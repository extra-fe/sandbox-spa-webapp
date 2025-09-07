import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { Logger, LogLevel } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const logLevel = (process.env.LOG_LEVEL ?? 'error') as LogLevel;
  Logger.overrideLogger([logLevel]);

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
