import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { HealthModule } from './health/health.module';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';

@Module({
  imports: [
    HealthModule,
    ConfigModule.forRoot({
      envFilePath:'.env'
    }),
    AuthModule,
],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}  
