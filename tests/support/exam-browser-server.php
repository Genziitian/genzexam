<?php
// Isolated integration fixture. Never expose this router on a public interface.
if (PHP_SAPI !== 'cli' && PHP_SAPI !== 'cli-server') exit;
if (getenv('EXAM_BROWSER_TEST') !== '1') { http_response_code(403); exit('Test mode required.'); }
$root = dirname(__DIR__, 2);
$fixture = getenv('EXAM_TEST_DIR');
if (!$fixture || !is_dir($fixture) || !(str_starts_with(realpath($fixture), realpath(sys_get_temp_dir()).DIRECTORY_SEPARATOR) || str_starts_with(realpath($fixture), realpath('/tmp').DIRECTORY_SEPARATOR))) throw new RuntimeException('Use a private temporary test directory.');
$uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
if (PHP_SAPI === 'cli-server' && !str_starts_with($uri, '/public/api/')) {
    if ($uri === '/exam-test-config.js') { header('Content-Type: text/javascript');echo 'window.QLStorefront={apiBase:"/public/api"};';return; }
    if (preg_match('~^/exams?(/.*)?$~', $uri)) {
        header('Content-Type: text/html');
        echo preg_replace('~<script src="/storefront-runtime\.js(?:\?[^\"]*)?" defer></script>~', '<script src="/exam-test-config.js" defer></script>', file_get_contents($root.'/exams.html')); return;
    }
    $file=realpath($root.$uri);
    if ($file && str_starts_with($file, $root.'/') && (str_starts_with($uri,'/assets/') || str_starts_with($uri,'/templates/') || in_array($uri,['/exam-platform.js','/exam-platform.css','/exam-rich-content.js']))) {
        $types=['js'=>'text/javascript','css'=>'text/css','json'=>'application/json','woff2'=>'font/woff2','woff'=>'font/woff','ttf'=>'font/ttf','png'=>'image/png'];
        header('Content-Type: '.($types[pathinfo($file, PATHINFO_EXTENSION)]??'application/octet-stream'));readfile($file);return;
    }
    http_response_code(404);exit;
}
require $root.'/backend/vendor/autoload.php';
$app = require $root.'/backend/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);
$kernel->bootstrap();
config(['app.env'=>'testing','app.debug'=>false,'app.key'=>'base64:'.base64_encode(str_repeat('t',32)),
    'database.default'=>'browser_test','database.connections.browser_test'=>['driver'=>'sqlite','database'=>$fixture.'/exam.sqlite','prefix'=>'','foreign_key_constraints'=>true],
    'cache.default'=>'array','session.driver'=>'array','logging.default'=>'stderr']);
Illuminate\Support\Facades\DB::purge('browser_test');
if (PHP_SAPI === 'cli') {
    if (file_exists($fixture.'/exam.sqlite')) throw new RuntimeException('Fixture already exists. Use a new temporary directory.');
    touch($fixture.'/exam.sqlite'); chmod($fixture.'/exam.sqlite',0600);
    Illuminate\Support\Facades\Schema::create('users',function(Illuminate\Database\Schema\Blueprint $t){
        $t->id();$t->string('name');$t->string('email')->unique();$t->string('role');$t->boolean('is_admin')->default(false);$t->boolean('is_active')->default(true);$t->timestamp('email_verified_at')->nullable();$t->timestamp('last_seen_at')->nullable();$t->string('password')->nullable();$t->timestamps();
    });
    Illuminate\Support\Facades\Schema::create('personal_access_tokens',function(Illuminate\Database\Schema\Blueprint $t){
        $t->id();$t->morphs('tokenable');$t->string('name');$t->string('token',64)->unique();$t->text('abilities')->nullable();$t->timestamp('last_used_at')->nullable();$t->timestamp('expires_at')->nullable();$t->timestamps();
    });
    (require $root.'/backend/database/migrations/2026_10_06_000001_create_proctored_exam_tables.php')->up();
    $tokens=[];
    foreach(['manager','student'] as $role){$u=App\Models\User::create(['name'=>'Test '.$role,'email'=>$role.'@example.test','role'=>$role,'is_active'=>true,'email_verified_at'=>now()]);$tokens[$role]=$u->createToken('browser-fixture')->plainTextToken;}
    file_put_contents($fixture.'/tokens.json',json_encode($tokens));chmod($fixture.'/tokens.json',0600);echo "Isolated exam browser fixture created.\n";exit;
}
$request=Illuminate\Http\Request::capture();$response=$kernel->handle($request);$response->send();$kernel->terminate($request,$response);
