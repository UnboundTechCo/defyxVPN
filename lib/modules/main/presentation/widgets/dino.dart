import 'dart:math';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

class DinoGame extends FlameGame with TapDetector, HasCollisionDetection {
  final AnimationService _animationService = AnimationService();
  late SpriteComponent dino;
  late SpriteComponent ground;
  late double gravity;
  double velocityY = 0;
  bool isJumping = false;
  bool isGameOver = false;
  bool isGameStarted = false;
  double groundOffset = 0;
  double groundSpeed = 300;

  final List<SpriteComponent> obstacles = [];
  final List<SpriteComponent> clouds = [];
  double spawnTimer = 0;
  double cloudSpawnTimer = 0;
  final double spawnInterval = 1.2;
  double cloudSpawnInterval = 3.0;
  bool isTouching = false;
  final double maxJumpTime = 0.19;
  double currentJumpTime = 0;
  double jumpPower = -500;
  double animationTimer = 0;
  final double animationInterval = 0.08;
  bool isFirstFrame = true;

  double distanceTraveled = 0;
  int score = 0;
  int highScore = 0;
  double gameTime = 0;
  final double baseSpeed = 300;
  final double speedIncrement = 20;

  late Sprite gameOverSprite;
  late Sprite restartSprite;
  late List<Sprite> numberSprites;
  late SpriteComponent gameOverComponent;
  late SpriteComponent startGameComponent;
  late SpriteComponent restartComponent;
  final List<SpriteComponent> scoreDigits = [];
  final List<SpriteComponent> highScoreDigits = [];

  late Sprite dinoSprite1;
  late Sprite dinoSprite2;
  late Sprite dinoDiedSprite;
  late Sprite groundSprite;
  late Sprite cactusSmall;
  late Sprite cactusLarge;
  late Sprite cloud;
  late Sprite startGameSprite;
  late Sprite highScoreText;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    gravity = 2500;

    final spriteImage = await images.load('game_assets.png');

    dinoSprite1 = Sprite(
      spriteImage,
      srcPosition: Vector2(176, 54),
      srcSize: Vector2(89, 97),
    );
    dinoSprite2 = Sprite(
      spriteImage,
      srcPosition: Vector2(296, 54),
      srcSize: Vector2(89, 97),
    );
    dinoDiedSprite = Sprite(
      spriteImage,
      srcPosition: Vector2(404, 79),
      srcSize: Vector2(115, 75),
    );
    groundSprite = Sprite(
      spriteImage,
      srcPosition: Vector2(56, 229),
      srcSize: Vector2(1300, 65),
    );
    cactusSmall = Sprite(
      spriteImage,
      srcPosition: Vector2(586, 88),
      srcSize: Vector2(56, 64),
    );
    cactusLarge = Sprite(
      spriteImage,
      srcPosition: Vector2(706, 54),
      srcSize: Vector2(56, 98),
    );
    cloud = Sprite(
      spriteImage,
      srcPosition: Vector2(1091, 87),
      srcSize: Vector2(94, 34),
    );
    highScoreText = Sprite(
      spriteImage,
      srcPosition: Vector2(156, 11),
      srcSize: Vector2(19, 11),
    );

    gameOverSprite = Sprite(
      spriteImage,
      srcPosition: Vector2(844, 77),
      srcSize: Vector2(175, 81),
    );
    startGameSprite = Sprite(
      spriteImage,
      srcPosition: Vector2(841, 43),
      srcSize: Vector2(241, 20),
    );

    restartSprite = Sprite(
      spriteImage,
      srcPosition: Vector2(2, 2),
      srcSize: Vector2(36, 32),
    );

    numberSprites = [];
    for (int i = 0; i < 10; i++) {
      numberSprites.add(
        Sprite(
          spriteImage,
          srcPosition: Vector2(56 + (i * 10), 11),
          srcSize: Vector2(9, 11),
        ),
      );
    }

    ground =
        SpriteComponent()
          ..sprite = groundSprite
          ..size = Vector2(size.x * 2, 25)
          ..position = Vector2(0, size.y - 12);
    add(ground);

    dino =
        SpriteComponent()
          ..sprite = dinoSprite1
          ..size = Vector2(40, 40)
          ..position = Vector2(50, size.y - 40);
    add(dino);

    gameOverComponent =
        SpriteComponent()
          ..sprite = gameOverSprite
          ..size = Vector2(175, 81)
          ..position = Vector2(size.x / 2, size.y / 2)
          ..anchor = Anchor.center;

    restartComponent =
        SpriteComponent()
          ..sprite = restartSprite
          ..size = Vector2(36, 32)
          ..position = Vector2(size.x / 2 - 18, size.y / 2)
          ..anchor = Anchor.center;

    startGameComponent =
        SpriteComponent()
          ..sprite = startGameSprite
          ..size = Vector2(241, 20)
          ..position = Vector2(size.x / 2, size.y / 2)
          ..anchor = Anchor.center;

    if (!isGameStarted && !isGameOver) {
      add(startGameComponent);
    }

    updateScoreDisplay();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isGameOver || !isGameStarted) {
      return;
    }

    gameTime += dt;
    distanceTraveled += groundSpeed * dt;

    int newScore = (distanceTraveled / 10).floor();
    if (newScore != score) {
      score = newScore;
      updateScoreDisplay();

      if (score > 0 && score % 100 == 0) {
        groundSpeed = baseSpeed + (score ~/ 100) * speedIncrement;
      }
    }

    groundOffset += groundSpeed * dt;
    if (groundOffset >= size.x) {
      groundOffset = 0;
    }
    ground.x = -groundOffset;

    if (!isJumping && _animationService.shouldAnimate()) {
      animationTimer += dt;
      if (animationTimer >= animationInterval) {
        animationTimer = 0;
        dino.sprite = isFirstFrame ? dinoSprite1 : dinoSprite2;
        isFirstFrame = !isFirstFrame;
      }
    }

    if (isJumping) {
      if (isTouching && currentJumpTime < maxJumpTime) {
        velocityY += gravity * dt * 0.15;
        currentJumpTime += dt;
      } else {
        velocityY += gravity * dt;
      }

      dino.y += velocityY * dt;

      if (dino.y >= size.y - 46) {
        dino.y = size.y - 46;
        velocityY = 0;
        isJumping = false;
      }
    }

    for (final obstacle in obstacles) {
      obstacle.x -= groundSpeed * dt;

      if (obstacle.x + obstacle.width < 0) {
        remove(obstacle);
      }

      if (obstacle.toRect().overlaps(dino.toRect())) {
        gameOver();
        return;
      }
    }

    obstacles.removeWhere((o) => o.x + o.width < 0);

    for (final cloudComponent in clouds) {
      cloudComponent.x -= (groundSpeed * 0.3) * dt;

      if (cloudComponent.x + cloudComponent.width < 0) {
        remove(cloudComponent);
      }
    }

    clouds.removeWhere((c) => c.x + c.width < 0);

    spawnTimer += dt;
    if (spawnTimer >= spawnInterval) {
      spawnObstacle();
      spawnTimer = 0;
    }

    cloudSpawnTimer += dt;
    if (cloudSpawnTimer >= cloudSpawnInterval) {
      spawnClouds();
      cloudSpawnTimer = 0;

      final random = Random();
      cloudSpawnInterval = 1.5 + random.nextDouble() * 4.5;
    }
  }

  void spawnObstacle() {
    final random = Random();

    final isSmallCactus = random.nextBool();
    final sprite = isSmallCactus ? cactusSmall : cactusLarge;

    int groupSize;
    if (isSmallCactus) {
      groupSize = random.nextInt(3) + 1;
    } else {
      groupSize = random.nextInt(2) + 1;
    }

    final baseX = size.x + 10;

    for (int i = 0; i < groupSize; i++) {
      double xOffset;
      if (isSmallCactus) {
        xOffset = i * 20.0;
      } else {
        xOffset = i * 22.0;
      }

      final width = isSmallCactus ? 16.0 : 22.0;
      final height = isSmallCactus ? 30.0 : 42.0;

      final heightVariation = 0.9 + (random.nextDouble() * 0.2);
      final finalHeight = height * heightVariation;

      final cactus =
          SpriteComponent()
            ..sprite = sprite
            ..size = Vector2(width, finalHeight)
            ..position = Vector2(baseX + xOffset, size.y - finalHeight);

      obstacles.add(cactus);
      add(cactus);
    }
  }

  void spawnClouds() {
    final random = Random();

    int cloudCount;
    final chance = random.nextDouble();
    if (chance < 0.4) {
      cloudCount = 1;
    } else if (chance < 0.7) {
      cloudCount = 2;
    } else if (chance < 0.9) {
      cloudCount = 3;
    } else {
      cloudCount = 4;
    }

    for (int i = 0; i < cloudCount; i++) {
      final minY = 20.0;
      final maxY = size.y * 0.4;
      final cloudY = minY + random.nextDouble() * (maxY - minY);

      final sizeMultiplier = 0.5 + random.nextDouble() * 0.3;
      final cloudWidth = 94 * sizeMultiplier;
      final cloudHeight = 34 * sizeMultiplier;

      final xOffset = i * (100 + random.nextDouble() * 200);

      final cloudComponent =
          SpriteComponent()
            ..sprite = cloud
            ..size = Vector2(cloudWidth, cloudHeight)
            ..position = Vector2(size.x + 50 + xOffset, cloudY);

      cloudComponent.paint =
          Paint()..color = const Color.fromRGBO(255, 255, 255, 0.7);

      clouds.add(cloudComponent);
      add(cloudComponent);
    }
  }

  void gameOver() {
    isGameOver = true;

    dino.sprite = dinoDiedSprite;

    if (score > highScore) {
      highScore = score;
      updateHighScoreDisplay();
    }

    add(gameOverComponent);
  }

  @override
  void onTap() {
    if (isGameOver) {
      resetGame();
    } else if (!isGameStarted) {
      isGameStarted = true;
      if (startGameComponent.isMounted) {
        remove(startGameComponent);
      }
    } else if (!isJumping) {
      velocityY = jumpPower;
      isJumping = true;
    }
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (isGameOver) {
      resetGame();
      return;
    }

    if (!isGameStarted) {
      if (startGameComponent.isMounted) {
        remove(startGameComponent);
      }
      isGameStarted = true;
      return;
    }

    if (!isJumping && dino.y >= size.y - 46) {
      isTouching = true;
      isJumping = true;
      velocityY = jumpPower;
      currentJumpTime = 0;
    }
  }

  @override
  void onTapUp(TapUpInfo info) {
    isTouching = false;
    if (startGameComponent.isMounted) {
      remove(startGameComponent);
    }
  }

  void resetGame() {
    isGameOver = false;
    isGameStarted = false;
    dino.y = size.y - 46;
    isJumping = false;
    velocityY = 0;
    groundOffset = 0;
    ground.x = 0;
    animationTimer = 0;
    isFirstFrame = true;
    dino.sprite = dinoSprite1;

    distanceTraveled = 0;
    score = 0;
    gameTime = 0;
    groundSpeed = baseSpeed;
    updateScoreDisplay();

    spawnTimer = 0;
    cloudSpawnTimer = 0;

    if (gameOverComponent.isMounted) {
      remove(gameOverComponent);
    }

    for (final o in obstacles) {
      remove(o);
    }
    obstacles.clear();

    for (final c in clouds) {
      remove(c);
    }
    clouds.clear();
  }

  void updateScoreDisplay() {
    for (final digit in scoreDigits) {
      if (digit.isMounted) remove(digit);
    }
    scoreDigits.clear();

    String scoreStr = score.toString().padLeft(5, '0');

    for (int i = 0; i < scoreStr.length; i++) {
      int digitValue = int.parse(scoreStr[i]);
      final digitSprite =
          SpriteComponent()
            ..sprite = numberSprites[digitValue]
            ..size = Vector2(9, 11)
            ..position = Vector2(size.x - 70 + (i * 12), 20);

      scoreDigits.add(digitSprite);
      add(digitSprite);
    }
  }

  void updateHighScoreDisplay() {
    for (final digit in highScoreDigits) {
      if (digit.isMounted) remove(digit);
    }
    highScoreDigits.clear();

    String highScoreStr = highScore.toString().padLeft(5, '0');

    final hiTextSprite =
        SpriteComponent()
          ..sprite = highScoreText
          ..size = Vector2(19, 11)
          ..position = Vector2(size.x - 195, 20);

    highScoreDigits.add(hiTextSprite);
    add(hiTextSprite);

    for (int i = 0; i < highScoreStr.length; i++) {
      int digitValue = int.parse(highScoreStr[i]);
      final digitSprite =
          SpriteComponent()
            ..sprite = numberSprites[digitValue]
            ..size = Vector2(9, 11)
            ..position = Vector2(size.x - 165 + (i * 12), 20);

      highScoreDigits.add(digitSprite);
      add(digitSprite);
    }
  }
}
