import { Controller, Get, Logger } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    Logger.debug("hoge");
    Logger.error("fuga");
    return this.appService.getHello();
  }
}
