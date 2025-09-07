import { Controller, Get, Logger, Req, UseGuards } from '@nestjs/common';
import { AppService } from './app.service';
import { JwtAuthGuard } from './auth/guards/jwt-auth.guard';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    Logger.debug("hoge");
    Logger.error("fuga");
    return this.appService.getHello();
  }
  @Get('api/guest/connect-test')
  connectTest() {
    Logger.debug("connect-test-debug");
    return { message: 'GET api/guest/connect-test ok', time: new Date().toISOString()};
  }

  @Get('api/protected')
  @UseGuards(JwtAuthGuard)
  getProtectedResource(@Req() req) {
    Logger.debug('GET api/protected ok');
    Logger.debug(`JWT payload: ${JSON.stringify(req.user)}`);
    return { message: 'GET api/protected', time: new Date().toISOString() };
  }
}
