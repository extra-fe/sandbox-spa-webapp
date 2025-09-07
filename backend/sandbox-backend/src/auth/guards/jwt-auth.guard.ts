import { Injectable, ExecutionContext, Logger } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest();

    // OPTIONS メソッドはスルー（プリフライト用）
    if (request.method === 'OPTIONS') {
      return true;
    }
    return super.canActivate(context);
  }
}  
