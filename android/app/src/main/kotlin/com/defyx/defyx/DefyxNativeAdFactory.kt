package de.unboundtech.defyxvpn

import android.content.Context
import android.graphics.Color
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.RatingBar
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * AdMob native card for the main screen's ad box (Dart factoryId
 * "defyxNative"; the iOS twin is DefyxNativeAdFactory in AppDelegate.swift).
 *
 * It fills whatever size the box gives it. Tall enough, it is laid out and
 * styled as Google's medium template was (which replaced it): the media on
 * top, the icon and headline row and the button below. In a shorter box that
 * would squeeze the media under AdMob's 120x120dp minimum, so there the media
 * is a square on the left with the headline, attribution and button beside
 * it.
 */
class DefyxNativeAdFactory(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView {
        val adView = NativeAdView(context)
        val card = DefyxNativeAdCard(context)
        adView.addView(
            card,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        card.bind(nativeAd, adView)
        return adView
    }

    companion object {
        const val FACTORY_ID = "defyxNative"
    }
}

/** The card's views, placed by hand in either arrangement. */
internal class DefyxNativeAdCard(context: Context) : ViewGroup(context) {
    private val media = MediaView(context)
    private val icon = ImageView(context)
    private val headline = TextView(context)
    private val badge = TextView(context)
    private val secondary = TextView(context)
    private val rating = RatingBar(context, null, android.R.attr.ratingBarStyleSmall)
    private val cta = TextView(context)

    // Side by side: the box is too short for the media on top.
    private var compact = false
    private val frames = HashMap<View, Rect>()

    init {
        setBackgroundColor(BACKGROUND)

        icon.scaleType = ImageView.ScaleType.FIT_CENTER

        headline.apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.DEFAULT_BOLD
            ellipsize = TextUtils.TruncateAt.END
            maxLines = 1
        }

        // Ad attribution, required on native ads.
        badge.apply {
            text = "Ad"
            gravity = Gravity.CENTER
            setTextColor(AD_GREEN)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            typeface = Typeface.DEFAULT_BOLD
            includeFontPadding = false
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                setStroke(dp(2f), AD_GREEN)
                cornerRadius = dp(5f).toFloat()
            }
        }

        secondary.apply {
            setTextColor(SECONDARY_TEXT)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            ellipsize = TextUtils.TruncateAt.END
            maxLines = 1
        }

        rating.apply {
            numStars = 5
            stepSize = 0.1f
            setIsIndicator(true)
        }

        cta.apply {
            setTextColor(BACKGROUND)
            setBackgroundColor(BRAND_YELLOW)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            ellipsize = TextUtils.TruncateAt.END
            maxLines = 1
            setPadding(dp(8f), 0, dp(8f), 0)
        }

        for (view in listOf(media, icon, headline, badge, secondary, rating, cta)) {
            addView(view)
        }
    }

    /** Fills the views and registers them, as the medium template did. */
    fun bind(ad: NativeAd, adView: NativeAdView) {
        headline.text = ad.headline
        adView.headlineView = headline
        adView.mediaView = media

        cta.text = ad.callToAction
        cta.visibility = if (ad.callToAction.isNullOrEmpty()) INVISIBLE else VISIBLE
        adView.callToActionView = cta

        val adIcon = ad.icon?.drawable
        if (adIcon != null) {
            icon.setImageDrawable(adIcon)
            icon.visibility = VISIBLE
            adView.iconView = icon
        } else {
            icon.visibility = GONE
        }

        val stars = ad.starRating
        if (stars != null && stars > 0) {
            rating.rating = stars.toFloat()
            rating.visibility = VISIBLE
            secondary.visibility = GONE
            adView.starRatingView = rating
        } else {
            rating.visibility = GONE
            secondary.visibility = VISIBLE
            val store = ad.store
            val advertiser = ad.advertiser
            when {
                !store.isNullOrEmpty() && advertiser.isNullOrEmpty() -> {
                    secondary.text = store
                    adView.storeView = secondary
                }
                !advertiser.isNullOrEmpty() -> {
                    secondary.text = advertiser
                    adView.advertiserView = secondary
                }
                else -> secondary.text = ""
            }
        }

        adView.setNativeAd(ad)
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val height =
            if (MeasureSpec.getMode(heightMeasureSpec) == MeasureSpec.UNSPECIFIED) {
                dp(FALLBACK_HEIGHT)
            } else {
                MeasureSpec.getSize(heightMeasureSpec)
            }
        setMeasuredDimension(width, height)

        val isCompact = height < dp(VERTICAL_MIN_HEIGHT)
        if (isCompact != compact) {
            compact = isCompact
            // Beside the media there is room for a second line.
            headline.maxLines = if (compact) 2 else 1
        }

        frames.clear()
        if (compact) measureCompact(width, height) else measureVertical(width, height)

        // Not placed in this arrangement (the icon in the compact one).
        val none = MeasureSpec.makeMeasureSpec(0, MeasureSpec.EXACTLY)
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            if (child.visibility != GONE && child !in frames) child.measure(none, none)
        }
    }

    // As Google's medium template: media on top; then a 52dp row with the
    // icon, headline and attribution; then the 40dp button. 5dp padding and
    // gaps.
    private fun measureVertical(width: Int, height: Int) {
        val pad = dp(5f)
        val inner = max(0, width - 2 * pad)
        val ctaHeight = dp(40f)
        val rowHeight = dp(52f)

        val ctaTop = height - pad - ctaHeight
        place(cta, pad, ctaTop, inner, ctaHeight)

        val rowTop = ctaTop - pad - rowHeight
        place(media, pad, pad, inner, max(0, rowTop - pad - pad))

        var textLeft = pad + dp(10f)
        if (icon.visibility != GONE) {
            place(icon, pad + dp(5f), rowTop, rowHeight, rowHeight)
            textLeft = pad + dp(5f) + rowHeight + dp(10f)
        }
        val textWidth = max(0, width - pad - textLeft)
        val headlineHeight = rowHeight / 2
        place(headline, textLeft, rowTop, textWidth, headlineHeight)
        placeAttribution(
            textLeft,
            rowTop + headlineHeight,
            textWidth,
            rowHeight - headlineHeight,
        )
    }

    // The media as a square on the left (as large as the height allows, at
    // most half the width); beside it the headline (two lines), the
    // attribution and, at the bottom, the button. No room for the icon.
    private fun measureCompact(width: Int, height: Int) {
        val pad = dp(5f)
        val side = max(0, min(height - 2 * pad, (width - 2 * pad) / 2))
        place(media, pad, (height - side) / 2, side, side)

        val textLeft = pad + side + dp(10f)
        val textWidth = max(0, width - pad - textLeft)
        val ctaHeight = dp(40f)
        place(cta, textLeft, height - pad - ctaHeight, textWidth, ctaHeight)

        headline.measure(
            MeasureSpec.makeMeasureSpec(textWidth, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(max(0, height - 2 * pad), MeasureSpec.AT_MOST),
        )
        frames[headline] =
            Rect(textLeft, pad, textLeft + textWidth, pad + headline.measuredHeight)
        placeAttribution(textLeft, pad + headline.measuredHeight + dp(4f), textWidth, dp(22f))
    }

    // The "Ad" badge, then the star rating or the advertiser / store.
    private fun placeAttribution(left: Int, top: Int, width: Int, height: Int) {
        val badgeWidth = dp(25f)
        place(badge, left, top, badgeWidth, min(dp(20f), height))

        val restLeft = left + badgeWidth + dp(10f)
        val restWidth = max(0, left + width - restLeft)
        if (rating.visibility != GONE) {
            rating.measure(
                MeasureSpec.makeMeasureSpec(restWidth, MeasureSpec.AT_MOST),
                MeasureSpec.makeMeasureSpec(height, MeasureSpec.AT_MOST),
            )
            frames[rating] = Rect(
                restLeft,
                top,
                restLeft + rating.measuredWidth,
                top + rating.measuredHeight,
            )
        }
        place(secondary, restLeft, top, restWidth, height)
    }

    private fun place(view: View, left: Int, top: Int, width: Int, height: Int) {
        if (view.visibility == GONE) return
        view.measure(
            MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY),
        )
        frames[view] = Rect(left, top, left + width, top + height)
    }

    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            val frame = frames[child]
            if (frame == null || child.visibility == GONE) {
                child.layout(0, 0, 0, 0)
            } else {
                child.layout(frame.left, frame.top, frame.right, frame.bottom)
            }
        }
    }

    override fun shouldDelayChildPressedState() = false

    private fun dp(value: Float): Int = (value * resources.displayMetrics.density).roundToInt()

    companion object {
        private const val BACKGROUND = 0xFF19312F.toInt()
        private const val BRAND_YELLOW = 0xFFFFC927.toInt()
        private const val AD_GREEN = 0xFF3A6728.toInt() // the template's badge
        private const val SECONDARY_TEXT = 0xB3FFFFFF.toInt() // white, 70%

        // The vertical arrangement keeps the media at AdMob's 120dp minimum
        // from this height on: 120 + 5 + 5 + 52 + 5 + 40 + 5.
        private const val VERTICAL_MIN_HEIGHT = 232f

        // If the height is not given (it always is, by the ad box).
        private const val FALLBACK_HEIGHT = 260f
    }
}
