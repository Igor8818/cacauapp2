package com.example.myapplication.userinterface.screens

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.myapplication.R
import kotlinx.coroutines.delay

private val MarromProfundo = Color(0xFF2B1810)
private val MarromEscuro = Color(0xFF1A0E09)
private val CremeCacau = Color(0xFFF5E9D3)
private val OuroCacau = Color(0xFFE9A83A)
private val VerdeFolha = Color(0xFF66BB6A)

/** Tempo mínimo que a splash fica visível, para a marca institucional ser lida com calma. */
private const val SPLASH_MINIMO_MS = 2200L

/** Teto de segurança: a splash nunca prende o usuário caso o carregamento demore. */
private const val SPLASH_MAXIMO_MS = 7000L

/**
 * Tela de abertura / carregamento com a identidade visual CacauApp.
 *
 * Permanece visível até que os dados persistidos ([dadosCarregados]) estejam lidos
 * e o tempo mínimo de exibição tenha passado, então chama [onConcluir].
 */
@Composable
fun SplashScreen(
    dadosCarregados: Boolean,
    onConcluir: () -> Unit
) {
    val progresso = remember { Animatable(0f) }
    val logoEscala = remember { Animatable(0.7f) }
    val logoAlpha = remember { Animatable(0f) }
    val rodapeAlpha = remember { Animatable(0f) }
    var minimoCumprido by remember { mutableStateOf(false) }

    // Entrada: logo com mola, depois a assinatura institucional
    LaunchedEffect(Unit) {
        logoAlpha.animateTo(1f, tween(600, easing = FastOutSlowInEasing))
    }
    LaunchedEffect(Unit) {
        logoEscala.animateTo(1f, spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow))
    }
    LaunchedEffect(Unit) {
        delay(500)
        rodapeAlpha.animateTo(1f, tween(700))
    }

    // Progresso "otimista" até 85%; os 15% finais só quando os dados realmente carregarem
    LaunchedEffect(Unit) {
        progresso.animateTo(0.85f, tween((SPLASH_MINIMO_MS - 300).toInt(), easing = LinearOutSlowInEasing))
    }
    LaunchedEffect(Unit) {
        delay(SPLASH_MINIMO_MS)
        minimoCumprido = true
    }
    LaunchedEffect(Unit) {
        delay(SPLASH_MAXIMO_MS)
        onConcluir()
    }
    LaunchedEffect(dadosCarregados, minimoCumprido) {
        if (dadosCarregados && minimoCumprido) {
            progresso.animateTo(1f, tween(300, easing = LinearEasing))
            delay(250)
            onConcluir()
        }
    }

    val transicaoInfinita = rememberInfiniteTransition(label = "splash_pulso")
    val brilho by transicaoInfinita.animateFloat(
        initialValue = 0.25f,
        targetValue = 0.55f,
        animationSpec = infiniteRepeatable(tween(1600, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "brilho"
    )

    val mensagem = when {
        progresso.value >= 1f -> "Tudo pronto!"
        progresso.value < 0.35f -> "Iniciando CacauApp…"
        progresso.value < 0.7f -> "Carregando dados de campo…"
        else -> "Preparando modelo de IA…"
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .pointerInput(Unit) {} // consome toques enquanto a splash está visível
            .background(Brush.verticalGradient(listOf(MarromProfundo, MarromEscuro))),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .navigationBarsPadding()
                .padding(horizontal = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.weight(1f))

            // Logo com halo dourado pulsante
            Box(contentAlignment = Alignment.Center) {
                Box(
                    Modifier
                        .size(250.dp)
                        .alpha(brilho * logoAlpha.value)
                        .background(
                            Brush.radialGradient(listOf(OuroCacau, Color.Transparent)),
                            RoundedCornerShape(50)
                        )
                )
                Image(
                    painter = painterResource(id = R.drawable.app_logo),
                    contentDescription = "Logo CacauApp",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(168.dp)
                        .scale(logoEscala.value)
                        .alpha(logoAlpha.value)
                        .clip(RoundedCornerShape(36.dp))
                        .border(1.5.dp, OuroCacau.copy(alpha = 0.5f), RoundedCornerShape(36.dp))
                )
            }

            Spacer(Modifier.height(28.dp))

            Text(
                "CacauApp",
                color = CremeCacau,
                fontSize = 32.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 1.sp,
                modifier = Modifier.alpha(logoAlpha.value)
            )
            Text(
                "Monitoramento inteligente de frutos de cacau",
                color = CremeCacau.copy(alpha = 0.72f),
                fontSize = 13.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .padding(top = 4.dp)
                    .alpha(logoAlpha.value)
            )

            Spacer(Modifier.height(36.dp))

            LinearProgressIndicator(
                progress = { progresso.value },
                modifier = Modifier
                    .width(200.dp)
                    .height(5.dp)
                    .clip(RoundedCornerShape(3.dp)),
                color = VerdeFolha,
                trackColor = CremeCacau.copy(alpha = 0.15f)
            )
            Spacer(Modifier.height(10.dp))
            Text(mensagem, color = CremeCacau.copy(alpha = 0.65f), fontSize = 12.sp)

            Spacer(Modifier.weight(1f))

            RodapeSplash(Modifier.alpha(rodapeAlpha.value))
            Spacer(Modifier.height(20.dp))
        }
    }
}

/**
 * Rodapé limpo da tela de abertura do aplicativo.
 */
@Composable
private fun RodapeSplash(modifier: Modifier = Modifier) {
    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            "VISÃO COMPUTACIONAL OFFLINE",
            color = OuroCacau,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 2.sp
        )
        Spacer(Modifier.height(6.dp))
        Text(
            "Monitoramento Inteligente de Campo",
            color = CremeCacau.copy(alpha = 0.78f),
            fontSize = 11.sp,
            textAlign = TextAlign.Center
        )
    }
}
