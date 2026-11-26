# Backend Plan — `GET /api/proyectos/by-easyredmine/{idEasyRedmine}`

Project: `projects/devx/gestor` (Symfony 6.4 + Doctrine MongoDB ODM, PHP >= 8.4).
Standards: `projects/devx/docs/backend-standards.md`, `projects/devx/docs/base-standards.md`.

## Key findings from codebase survey (read this before coding)

1. **No PHPUnit test infrastructure exists yet.** There is no `tests/` directory, no `phpunit.xml(.dist)`, and `composer.json` `require-dev` only has `symfony/maker-bundle`. `docs/backend-standards.md` documents KernelTestCase/WebTestCase as the intended approach, but it has never been wired up. **This must be bootstrapped first**, otherwise there is nothing to run TDD against.
2. Security: firewall `main` in `config/packages/security.yaml` protects everything by default (`access_control: - { path: ^/, roles: ROLE_USER }`), with explicit `PUBLIC_ACCESS` exceptions only for `/saml/`, `/login`, `/sesion-cerrada`, `/api/cfg`, `/v1/cfg`. Existing read endpoints like `ProyectoController::list()` / `ramas()` carry **no** `#[IsGranted]` attribute — they rely purely on the firewall's default `ROLE_USER` requirement. The new endpoint must follow the same convention: **no explicit `#[IsGranted]`, no change to `security.yaml`** (its path `^/api/proyectos` is not in the `PUBLIC_ACCESS` list, so it falls through to the catch-all `ROLE_USER` rule — same protection as `ProyectoController`).
3. User model is `Symfony\Component\Security\Core\User\InMemoryUser` (loaded via `App\Security\DevxUserProvider`, which is just a whitelist `login => {password, roles}` from `config/packages/dev/saml.yaml`). This is what tests must authenticate as, via `$client->loginUser(new InMemoryUser(...))`.
4. Repository pattern already used in the codebase for exactly this lookup (`src/Command/ImportActuacionesFromEasyRedmineCommand.php`): `$this->dm->getRepository(Proyecto::class)->findOneBy(['idEasyRedmine' => $id])`. Reuse this — do not call `findAll()` and filter in PHP.
5. `Proyecto::getIdEasyRedmine()`, `getNombre()`, `getRepositorio()`, `getRepositorioGithub()`, `getVcsPrincipal()` already exist and are typed (`?string`, `string`, `string`, `?string`, `string` respectively). No document changes needed.
6. Existing JSON API controllers live under `src/Controller/Api/` (`CfgIngestController.php`, `CfgV1IngestController.php`) and return `JsonResponse` via `$this->json(...)`. Follow that location/style — this endpoint is a *new* API controller, not an addition to `src/Controller/ProyectoController.php` (which is HTML/Twig + form-oriented, prefixed `/proyectos`, not `/api/proyectos`).
7. Error messages elsewhere in the codebase (`ProyectoController::eliminar`, `limpiarRamasObsoletas`, etc.) are in **Spanish** (`'Proyecto no encontrado.'`, `'Token de seguridad inválido.'`). Follow that convention for the 404 message, matching the task's own suggested text.
8. Dev MongoDB is a **remote, read-only** tunnel in this environment (per project conventions) — do not design a test that requires inserting/seeding a real `Proyecto` document into the shared dev database. The test must isolate the `DocumentManager`/repository behavior from the real DB (see Testing section below).
9. No OpenSpec change exists for this feature per the task instructions ("no toques OpenSpec") — proceed as a direct code change in the working tree.

## Files to create / modify

### 1. Bootstrap PHPUnit (new — required, currently missing)

**`projects/devx/gestor/composer.json`** — add to `require-dev`:
```json
"require-dev": {
    "symfony/maker-bundle": "^1.50",
    "symfony/phpunit-bridge": "^6.4",
    "symfony/browser-kit": "^6.4",
    "symfony/css-selector": "^6.4"
}
```
(`symfony/phpunit-bridge` pulls PHPUnit itself and provides `bin/phpunit`; `browser-kit`/`css-selector` are required by `WebTestCase`.) Run `composer update` after editing (do this as a dependency-install step, not part of the "minimal code to pass" implementation — flag it to whoever executes the plan).

**`projects/devx/gestor/phpunit.xml.dist`** (new file):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="https://schema.phpunit.de/9.6/phpunit.xsd"
         bootstrap="tests/bootstrap.php"
         colors="true"
         failOnWarning="true"
         failOnRisky="true">
    <testsuites>
        <testsuite name="default">
            <directory>tests</directory>
        </testsuite>
    </testsuites>
    <source>
        <include>
            <directory>src</directory>
        </include>
    </source>
    <php>
        <ini name="error_reporting" value="-1" />
        <server name="APP_ENV" value="test" force="true" />
        <server name="SHELL_VERBOSITY" value="-1" />
    </php>
</phpunit>
```
Adjust the `xsi:noNamespaceSchemaLocation` PHPUnit version to whatever `symfony/phpunit-bridge` actually resolves (check `vendor/phpunit/phpunit/phpunit.xsd` after `composer update`); do not guess blindly if it mismatches.

**`projects/devx/gestor/tests/bootstrap.php`** (new file):
```php
<?php

use Symfony\Component\Dotenv\Dotenv;

require dirname(__DIR__).'/vendor/autoload.php';

if (method_exists(Dotenv::class, 'bootEnv')) {
    (new Dotenv())->bootEnv(dirname(__DIR__).'/.env');
}
```
(Mirrors the root `bootstrap.php` so `APP_ENV=test` and env vars load for the kernel.)

**`projects/devx/gestor/.env.test`** (new file, minimal — only if the kernel requires `APP_ENV=test` overrides; in most Symfony Flex apps this file can be empty or omitted entirely since `APP_ENV` is forced via phpunit.xml `<server>`). Create it only if boot fails without it; otherwise skip to keep the change minimal.

### 2. New API controller

**`projects/devx/gestor/src/Controller/Api/ProyectoApiController.php`** (new file):

```php
<?php

namespace App\Controller\Api;

use App\Document\Proyecto;
use Doctrine\ODM\MongoDB\DocumentManager;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/proyectos')]
class ProyectoApiController extends AbstractController
{
    public function __construct(
        private DocumentManager $dm,
    ) {
    }

    #[Route('/by-easyredmine/{idEasyRedmine}', name: 'api_proyectos_by_easyredmine', methods: ['GET'])]
    public function byEasyRedmine(string $idEasyRedmine): JsonResponse
    {
        /** @var Proyecto|null $proyecto */
        $proyecto = $this->dm->getRepository(Proyecto::class)->findOneBy(['idEasyRedmine' => $idEasyRedmine]);

        if ($proyecto === null) {
            return $this->json(['error' => 'Proyecto no encontrado'], Response::HTTP_NOT_FOUND);
        }

        return $this->json([
            'idEasyRedmine' => $proyecto->getIdEasyRedmine(),
            'nombre' => $proyecto->getNombre(),
            'repositorio' => $proyecto->getRepositorio(),
            'repositorioGithub' => $proyecto->getRepositorioGithub(),
            'vcsPrincipal' => $proyecto->getVcsPrincipal(),
        ]);
    }
}
```

Notes:
- Route prefix `/api/proyectos` is new — distinct from the existing `/proyectos` (Twig) and `/api/cfg`, `/v1/cfg` (public ingest) prefixes. No collision.
- No `#[IsGranted]` attribute, consistent with `ProyectoController` read actions (point 2 above) — protection comes from the firewall's default `ROLE_USER` access_control rule.
- Single public method, constructor DI only, thin controller delegating only to the repository (no extra service needed — this is a pure lookup + serialization, consistent with "Controllers: validate HTTP input, call a service" where the "service" here is the ODM repository itself, same pattern as `ProyectoController::ramas()` using `$this->dm->getRepository(Proyecto::class)->find($id)` directly). If reviewers prefer business logic strictly out of controllers per `docs/backend-standards.md` §Services ("business logic lives exclusively in `src/Service/`"), this is borderline — but a single `findOneBy` + field projection is the same level of logic other controllers in this codebase already keep inline (see `ProyectoController::ramas()`, `eliminarRama()`), so no new service class is proposed. Flag this as a judgment call if the user wants a dedicated `ProyectoLookupService` instead.
- `idEasyRedmine` route parameter stays a plain `string`; no extra validation needed since `findOneBy` with a non-matching string simply returns `null` → 404 (safe, no injection risk via ODM's typed query builder).

### 3. Routes

No `config/routes.yaml` changes needed — this project uses `#[Route]` attributes with attribute-based route loading (confirm via `config/routes.yaml` / `config/routes/attributes.yaml` that `src/Controller/` is already scanned; it is, since `CfgIngestController` and `ProyectoController` already work this way).

### 4. Tests (write first, must fail, then implement controller to pass)

**`projects/devx/gestor/tests/Controller/Api/ProyectoApiControllerTest.php`** (new file):

Use `WebTestCase` and replace the `DocumentManager`'s `Proyecto` repository behavior via a test double registered in the test container — do **not** hit the real (remote, read-only) MongoDB. Two viable approaches; pick the one that matches how the Symfony kernel is actually wired once bootstrap exists (verify after step 1 lands):

**Approach A (preferred, simplest): stub the repository via a fake `DocumentManager`.**
Since the controller only calls `$this->dm->getRepository(Proyecto::class)->findOneBy([...])`, create a minimal test double for `DocumentManager` (or decorate the repository) and inject it into the test client's container with `static::getContainer()->set(DocumentManager::class, $fakeDm)`. Example skeleton:

```php
<?php

namespace App\Tests\Controller\Api;

use App\Document\Proyecto;
use Doctrine\ODM\MongoDB\DocumentManager;
use Doctrine\ODM\MongoDB\Repository\DocumentRepository;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\Security\Core\User\InMemoryUser;

class ProyectoApiControllerTest extends WebTestCase
{
    public function testReturnsProyectoWhenFoundByEasyRedmineId(): void
    {
        $proyecto = (new Proyecto())
            ->setNombre('Gestor devX')
            ->setRepositorio('retain/devx/gestor')
            ->setRepositorioGithub('RetainTechnologiesSL/gestor')
            ->setVcsPrincipal(Proyecto::VCS_GITHUB);
        $proyecto->setIdEasyRedmine('1234');

        $repository = $this->createMock(DocumentRepository::class);
        $repository->method('findOneBy')
            ->with(['idEasyRedmine' => '1234'])
            ->willReturn($proyecto);

        $dm = $this->createMock(DocumentManager::class);
        $dm->method('getRepository')->with(Proyecto::class)->willReturn($repository);

        $client = static::createClient();
        static::getContainer()->set(DocumentManager::class, $dm);
        $client->loginUser(new InMemoryUser('fran.parreno', null, ['ROLE_USER']));

        $client->request('GET', '/api/proyectos/by-easyredmine/1234');

        self::assertResponseIsSuccessful();
        $data = json_decode($client->getResponse()->getContent(), true);
        self::assertSame('1234', $data['idEasyRedmine']);
        self::assertSame('Gestor devX', $data['nombre']);
        self::assertSame('retain/devx/gestor', $data['repositorio']);
        self::assertSame('RetainTechnologiesSL/gestor', $data['repositorioGithub']);
        self::assertSame(Proyecto::VCS_GITHUB, $data['vcsPrincipal']);
    }

    public function testReturns404WhenProyectoNotFound(): void
    {
        $repository = $this->createMock(DocumentRepository::class);
        $repository->method('findOneBy')
            ->with(['idEasyRedmine' => 'missing'])
            ->willReturn(null);

        $dm = $this->createMock(DocumentManager::class);
        $dm->method('getRepository')->with(Proyecto::class)->willReturn($repository);

        $client = static::createClient();
        static::getContainer()->set(DocumentManager::class, $dm);
        $client->loginUser(new InMemoryUser('fran.parreno', null, ['ROLE_USER']));

        $client->request('GET', '/api/proyectos/by-easyredmine/missing');

        self::assertResponseStatusCodeSame(404);
        $data = json_decode($client->getResponse()->getContent(), true);
        self::assertSame('Proyecto no encontrado', $data['error']);
    }
}
```

Important caveats the implementer must verify/adjust before trusting this verbatim:
- `DocumentRepository` is abstract; `createMock()` on an abstract class works fine with PHPUnit as long as it has no `final` methods blocking mocking — verify `Doctrine\ODM\MongoDB\Repository\DocumentRepository::findOneBy` is not `final` (it is not, as of ODM 4.x, but confirm against the installed version in `vendor/doctrine/mongodb-odm`).
- `DocumentManager::getRepository()` return type is `ObjectRepository`; mocking the concrete `DocumentManager` class itself may fail if it has a non-mockable constructor or final methods — if `createMock(DocumentManager::class)` errors, fall back to mocking the `ObjectRepository` interface only and wrapping it behind a real `DocumentManager` test double via `$this->getMockBuilder(DocumentManager::class)->disableOriginalConstructor()->onlyMethods(['getRepository'])->getMock()`.
- `static::getContainer()->set(DocumentManager::class, $dm)` requires `framework.test: true` (already standard in `config/packages/test/framework.yaml`, which must be created alongside `phpunit.xml.dist` if missing — check `config/packages/test/` exists; create `config/packages/test/framework.yaml` with `framework:\n    test: true` if absent).
- `InMemoryUser` login string is arbitrary for the test (it does not need to match a real `config/packages/dev/saml.yaml` entry) since `loginUser()` bypasses the `DevxUserProvider` and installs the token directly — verify this assumption holds for this Symfony version; if `loginUser()` round-trips through the provider's `refreshUser()`, use a login that actually exists in `config/packages/dev/saml.yaml` instead (check that file's contents first).
- Confirm `config/packages/test/security.yaml` is not needed — if the `main` firewall requires session cookies or CSRF that break `WebTestCase` requests, check for existing precedent; since no tests exist yet, this is uncharted and should be validated by actually running the test, not assumed.

**Approach B (fallback, if `DocumentManager` cannot be cleanly mocked):** write a thin `ProyectoLookupService` in `src/Service/` wrapping the `findOneBy` call, inject *that* into the controller, and mock the service directly in the test (simpler mock target, cleaner DI boundary, and better aligned with the "business logic in `src/Service/`" rule from `backend-standards.md`). This also resolves the point-2-under-controller-notes judgment call above. If Approach A's mocking of `DocumentManager`/`DocumentRepository` proves awkward, switch to Approach B:
  - New file `src/Service/ProyectoLookupService.php`:
    ```php
    <?php

    namespace App\Service;

    use App\Document\Proyecto;
    use Doctrine\ODM\MongoDB\DocumentManager;

    class ProyectoLookupService
    {
        public function __construct(
            private DocumentManager $dm,
        ) {
        }

        public function findByEasyRedmineId(string $idEasyRedmine): ?Proyecto
        {
            return $this->dm->getRepository(Proyecto::class)->findOneBy(['idEasyRedmine' => $idEasyRedmine]);
        }
    }
    ```
  - Controller injects `ProyectoLookupService` instead of `DocumentManager` directly and calls `$this->lookup->findByEasyRedmineId($idEasyRedmine)`.
  - Test mocks `ProyectoLookupService` via `static::getContainer()->set(ProyectoLookupService::class, $mock)` — much simpler mock surface.

**Recommendation:** start with Approach B directly; it is both easier to test reliably and better matches the documented architecture ("business logic lives exclusively in `src/Service/`"), avoiding the controller talking to `DocumentManager` at all. Only the `Proyecto`-field-to-array mapping remains in the controller, which is acceptable presentation-layer work.

### 5. No changes needed to

- `src/Document/Proyecto.php` — all required fields/getters already exist.
- `config/packages/security.yaml` — new route inherits default `ROLE_USER` protection.
- `config/routes.yaml` / `config/routes/attributes.yaml` — attribute-based routing already covers `src/Controller/`.
- `docs/api-spec.yml` — out of scope per task instructions (not requested), but flag to the user that this file exists and documents `POST /api/v1/cfg`; consider asking whether the new endpoint should be documented there too (not done by this plan, since not explicitly requested).

## Step-by-step implementation order (incremental, TDD)

1. Add `symfony/phpunit-bridge`, `symfony/browser-kit`, `symfony/css-selector` to `composer.json` `require-dev`; run `composer update` (or `composer require --dev ...`).
2. Create `phpunit.xml.dist`, `tests/bootstrap.php`, and `config/packages/test/framework.yaml` (with `test: true`) if not already present after the composer update (Symfony Flex may auto-create some of these via recipes — check before hand-writing).
3. Write `tests/Controller/Api/ProyectoApiControllerTest.php` (Approach B target API) — run it, confirm it fails with "class ProyectoLookupService not found" / 404 route missing (red).
4. Create `src/Service/ProyectoLookupService.php`.
5. Create `src/Controller/Api/ProyectoApiController.php` using the service.
6. Run `php bin/phpunit tests/Controller/Api/ProyectoApiControllerTest.php` — confirm both cases pass (green).
7. Re-run to confirm no regressions in startup/boot (since this is the first PHPUnit run ever in this project, watch for unrelated container compilation errors — e.g. missing env vars like `GITLAB_TOKEN`, S3 vars for `RecursoExplorerService` — and report them rather than silently patching unrelated services).

## Open questions / deviations to confirm with the user

1. **No test framework existed before this task.** Bootstrapping it (steps 1–2) is a prerequisite not mentioned explicitly in the original request; flag this clearly when reporting results.
2. Controller vs. service split (Approach A vs. B) is a judgment call — this plan recommends Approach B (new `ProyectoLookupService`) for testability and standards alignment, but it's a slightly larger diff than the strict "just the endpoint" ask. If the user wants the absolute minimal diff, Approach A (direct `DocumentManager` use in the controller, mirroring `ProyectoController::ramas()`) is acceptable too — just harder to unit-test cleanly.
3. Confirm whether `loginUser()` in `WebTestCase` bypasses `DevxUserProvider::refreshUser()` in the Symfony version pinned here (`symfony/security-bundle: ^7.2` while the rest of the framework is `^6.4` — mixed versions already present in `composer.json`, worth double-checking compatibility before assuming `WebTestCase`/`loginUser()` behavior).
